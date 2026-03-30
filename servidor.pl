:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_files)).
:- use_module(library(csv)).

% 1. Configurar rutas del servidor
:- http_handler(root(api/temperatura), api_temperatura, []).
:- http_handler(root(api/milivoltios), api_milivoltios, []).
:- http_handler(root(api/comparar), api_comparar, []).
:- http_handler(root(.), http_reply_from_files('.', []), [prefix]).

% 2. Iniciar el servidor
iniciar_servidor :-
    http_server(http_dispatch, [port(8080)]),
    writeln('Servidor iniciado. Ve a http://localhost:8080/index.html').

% 3. Lógica del API
api_temperatura(Request) :-
    http_parameters(Request, [
        tipo(Tipo, [atom, oneof([k, j, t])]),
        mv(MV_Str, [string])
    ]),
    ( convertir_mv(MV_Str, MV) ->
        atomic_list_concat(['tabla_', Tipo, '.txt'], NombreArchivo),
        ( exists_file(NombreArchivo),
          buscar_e_interpolar(NombreArchivo, MV, Temperatura) ->
            clasificar_estado(Tipo, Temperatura, Estado, MensajeEstado),
            reply_json(dict{
                status: "success",
                temperatura: Temperatura,
                estado: Estado,
                mensaje_estado: MensajeEstado
            })
        ;
            reply_json(dict{status: "error", mensaje: "Valor fuera de rango en la tabla"})
        )
    ;
        reply_json(dict{status: "error", mensaje: "El valor de mV no es valido"})
    ).

api_milivoltios(Request) :-
    http_parameters(Request, [
        tipo(Tipo, [atom, oneof([k, j, t])]),
        temperatura(Temp_Str, [string])
    ]),
    ( convertir_numero(Temp_Str, Temp) ->
        atomic_list_concat(['tabla_', Tipo, '.txt'], NombreArchivo),
        ( exists_file(NombreArchivo),
          buscar_e_interpolar_temp_mV(NombreArchivo, Temp, Milivoltios) ->
            clasificar_estado(Tipo, Temp, Estado, MensajeEstado),
            reply_json(dict{
                status: "success",
                milivoltios: Milivoltios,
                estado: Estado,
                mensaje_estado: MensajeEstado
            })
        ;
            reply_json(dict{status: "error", mensaje: "Temperatura fuera de rango en la tabla"})
        )
    ;
        reply_json(dict{status: "error", mensaje: "El valor de temperatura no es valido"})
    ).

api_comparar(Request) :-
    http_parameters(Request, [
        modo(Modo, [atom, oneof([mv_a_temp, temp_a_mv])]),
        valor(Valor_Str, [string])
    ]),
    ( convertir_numero(Valor_Str, Valor) ->
        findall(Resultado,
                resultado_comparacion(Modo, Valor, Resultado),
                Comparacion),
        reply_json(dict{status: "success", comparacion: Comparacion})
    ;
        reply_json(dict{status: "error", mensaje: "El valor para comparar no es valido"})
    ).

convertir_mv(MV_Str, MV) :-
    convertir_numero(MV_Str, MV).

convertir_numero(Valor_Str, Numero) :-
    catch(number_string(Numero, Valor_Str), _, fail),
    number(Numero).

tipos_termocupla([k, j, t]).

tipo_nombre(k, "Tipo K").
tipo_nombre(j, "Tipo J").
tipo_nombre(t, "Tipo T").

tipo_limites(k, -270, 1372).
tipo_limites(j, -210, 1200).
tipo_limites(t, -270, 400).

clasificar_estado(Tipo, Temp, Estado, Mensaje) :-
    tipo_limites(Tipo, Min, Max),
    ( (Temp < Min ; Temp > Max) ->
        Estado = "peligro",
        Mensaje = "Fuera del rango recomendado para esta termocupla"
    ;
        Rango is Max - Min,
        Margen is Rango * 0.1,
        LimInf is Min + Margen,
        LimSup is Max - Margen,
        ( (Temp =< LimInf ; Temp >= LimSup) ->
            Estado = "advertencia",
            Mensaje = "Cerca del limite operativo de la termocupla"
        ;
            Estado = "normal",
            Mensaje = "Dentro del rango operativo recomendado"
        )
    ).

resultado_comparacion(Modo, Valor, Resultado) :-
    tipos_termocupla(Tipos),
    member(Tipo, Tipos),
    tipo_nombre(Tipo, TipoNombre),
    atomic_list_concat(['tabla_', Tipo, '.txt'], NombreArchivo),
    ( exists_file(NombreArchivo) ->
        comparacion_desde_tabla(Modo, Tipo, TipoNombre, NombreArchivo, Valor, Resultado)
    ;
        Resultado = dict{
            tipo: TipoNombre,
            tipo_id: Tipo,
            status: "error",
            mensaje: "No se encontro la tabla para esta termocupla"
        }
    ).

comparacion_desde_tabla(mv_a_temp, Tipo, TipoNombre, Archivo, ValorMV, Resultado) :-
    ( buscar_e_interpolar(Archivo, ValorMV, Temperatura) ->
        clasificar_estado(Tipo, Temperatura, Estado, MensajeEstado),
        Resultado = dict{
            tipo: TipoNombre,
            tipo_id: Tipo,
            status: "success",
            resultado: Temperatura,
            unidad: "C",
            estado: Estado,
            mensaje_estado: MensajeEstado
        }
    ;
        Resultado = dict{
            tipo: TipoNombre,
            tipo_id: Tipo,
            status: "error",
            mensaje: "Valor fuera de rango en la tabla"
        }
    ).

comparacion_desde_tabla(temp_a_mv, Tipo, TipoNombre, Archivo, ValorTemp, Resultado) :-
    ( buscar_e_interpolar_temp_mV(Archivo, ValorTemp, Milivoltios) ->
        clasificar_estado(Tipo, ValorTemp, Estado, MensajeEstado),
        Resultado = dict{
            tipo: TipoNombre,
            tipo_id: Tipo,
            status: "success",
            resultado: Milivoltios,
            unidad: "mV",
            estado: Estado,
            mensaje_estado: MensajeEstado
        }
    ;
        Resultado = dict{
            tipo: TipoNombre,
            tipo_id: Tipo,
            status: "error",
            mensaje: "Valor fuera de rango en la tabla"
        }
    ).

% 4. Leer el archivo y mandar a interpolar
buscar_e_interpolar(Archivo, MV, TempFinal) :-
    csv_read_file(Archivo, Filas, [separator(44)]),
    preparar_puntos_por_mv(Filas, PuntosOrdenados),
    interpolar(PuntosOrdenados, MV, TempCalc),
    TempFinal is round(TempCalc * 100) / 100.

buscar_e_interpolar_temp_mV(Archivo, Temp, MVFinal) :-
    csv_read_file(Archivo, Filas, [separator(44)]),
    preparar_puntos_por_temp(Filas, PuntosOrdenados),
    interpolar(PuntosOrdenados, Temp, MVCalc),
    MVFinal is round(MVCalc * 1000) / 1000.

preparar_puntos_por_mv(Filas, PuntosOrdenados) :-
    maplist(fila_a_punto, Filas, Puntos),
    keysort(Puntos, PuntosOrdenados).

preparar_puntos_por_temp(Filas, PuntosOrdenados) :-
    maplist(fila_a_punto_invertido, Filas, Puntos),
    keysort(Puntos, PuntosOrdenados).

fila_a_punto(row(MV0, T0), MV-T) :-
    numero_desde(MV0, MV),
    numero_desde(T0, T).

fila_a_punto_invertido(row(MV0, T0), T-MV) :-
    numero_desde(MV0, MV),
    numero_desde(T0, T).

numero_desde(Valor, Numero) :-
    ( number(Valor) ->
        Numero = Valor
    ; atom(Valor) ->
        atom_number(Valor, Numero)
    ; string(Valor) ->
        number_string(Numero, Valor)
    ).

interpolar([MV-T | _], V, T) :-
    V =:= MV,
    !.

interpolar([MV1-T1, MV2-T2 | _], V, Temp) :-
    en_rango(V, MV1, MV2),
    DeltaMV is MV2 - MV1,
    DeltaMV =\= 0,
    Temp is T1 + ((V - MV1) / DeltaMV) * (T2 - T1),
    !.

interpolar([_ | Resto], V, Temp) :-
    interpolar(Resto, V, Temp).

en_rango(V, A, B) :-
    (V >= A, V =< B)
    ;
    (V >= B, V =< A).