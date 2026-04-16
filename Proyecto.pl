:- use_module(library(pce)).
:- use_module(library(csv)).

% ==========================================
% 1. INTERFAZ GRÁFICA (XPCE)
% ==========================================

iniciar_app :-
    % Crear ventana, ajustar tamaño y centrarla
    new(D, dialog('Conversor de Termocuplas')),
    send(D, size, size(560, 680)),
    
    % Titulo principal
    send(D, append, new(Tit, label(titulo_principal, 'Calculadora de Termocuplas'))),
    send(Tit, font, font(helvetica, bold, 18)),
    
    % Grupo 1: Configuración
    send(D, append, new(GrpConfig, dialog_group('1. Configuracion del Sensor', box))),
    send(GrpConfig, append, new(TipoMenu, menu(tipo, cycle))),
    send(TipoMenu, append, k),
    send(TipoMenu, append, j),
    send(TipoMenu, append, t),
    send(TipoMenu, selection, k), % valor por defecto
    
    send(GrpConfig, append, new(ModoMenu, menu(modo, cycle)), right),
    send(ModoMenu, append, 'mV a Grados'),
    send(ModoMenu, append, 'Grados a mV'),
    send(ModoMenu, selection, 'mV a Grados'), % modo por defecto
    
    % Grupo 2: Entrada
    send(D, append, new(GrpDatos, dialog_group('2. Entrada de Datos', box))),
    
    send(GrpDatos, append, new(ValItem, text_item(valor))),
    send(ValItem, length, 14),
    send(ValItem, selection, '0'),
    
    send(GrpDatos, append, new(OffsetItem, text_item(offset, '0')), right),
    send(OffsetItem, label, 'Offset '),
    send(OffsetItem, length, 8),
    
    % Grupo 3: Resultado (Destacado)
    send(D, append, new(GrpRes, dialog_group('Resultado y Estado', box))),
    send(GrpRes, append, new(ResLabel, label(resultado, 'Resultado: --'))),
    send(ResLabel, font, font(helvetica, bold, 24)),
    send(ResLabel, colour, colour(blue)),

    send(GrpRes, append, new(StatusLabel, label(status, ''))),
    send(StatusLabel, font, font(helvetica, italic, 11)),
    send(StatusLabel, colour, colour(gray)),
    
    % Botones principales
    send(D, append, new(CalcBtn, button('  CALCULAR  ', message(@prolog, calcular, D)))),
    send(CalcBtn, font, font(helvetica, bold, 14)),
    send(D, append, new(_ClearBtn, button('Limpiar', message(@prolog, limpiar, D))), right),

    % Sección de Historial
    send(D, append, new(GrpHist, dialog_group('Historial de Conversiones', box))),
    send(GrpHist, append, new(Historial, list_browser)),
    send(Historial, name, historial_lista),
    send(Historial, width, 65),
    send(Historial, height, 8), % Muestra hasta 8 líneas a la vez
    send(Historial, font, font(helvetica, normal, 10)),
    
    % Boton Salir
    send(D, append, new(_ExitBtn, button('Salir', message(D, destroy)))),
    
    % Mostrar ventana
    send(D, open_centered).

% ==========================================
% 2. LÓGICA DE LA INTERFAZ
% ==========================================

calcular(D) :-
    % Obtener datos de la ventana
    get(D, member, '1. Configuracion del Sensor', GrpConfig),
    get(GrpConfig, member, tipo, TipoMenu), get(TipoMenu, selection, Tipo),
    get(GrpConfig, member, modo, ModoMenu), get(ModoMenu, selection, Modo),
    
    get(D, member, '2. Entrada de Datos', GrpDatos),
    get(GrpDatos, member, valor, ValItem), get(ValItem, selection, ValText),
    get(GrpDatos, member, offset, OffsetItem), get(OffsetItem, selection, OffsetText),
    
    (   parsear_numero(ValText, ValNum) ->
        (   parsear_numero(OffsetText, Offset) ->
            (   archivo_tabla(Tipo, Archivo) ->
                % Decidir qué formula usar según el Modo seleccionado
                (   Modo == 'mV a Grados' ->
                    (   buscar_mv_c(Archivo, ValNum, ResBase) ->
                        Res is round((ResBase + Offset) * 100) / 100,
                        atomic_list_concat(['Resultado: ', Res, ' C'], LblTxt),
                        atomic_list_concat(['[Tipo ', Tipo, '] ', ValNum, ' mV  =  ', Res, ' C (offset ', Offset, ')'], HistTxt),
                        EstadoMsg = 'Conversion correcta.:)'
                    ;
                        LblTxt = 'Error: Fuera de rango', HistTxt = 'Error: Valor fuera de limites', EstadoMsg = 'Error: fuera de rango'
                    )
                ;
                    % Modo: Grados a mV
                    (   buscar_c_mv(Archivo, ValNum, ResBase) ->
                        Res is round((ResBase + Offset) * 1000) / 1000,
                        atomic_list_concat(['Resultado: ', Res, ' mV'], LblTxt),
                        atomic_list_concat(['[Tipo ', Tipo, '] ', ValNum, ' C  =  ', Res, ' mV (offset ', Offset, ')'], HistTxt),
                        EstadoMsg = 'Conversion correcta.'
                    ;
                        LblTxt = 'Error: Fuera de rango', HistTxt = 'Error: Valor fuera de limites', EstadoMsg = 'Error: fuera de rango'
                    )
                ),
                % 1. Actualizar el Label del resultado
                get(D, member, 'Resultado y Estado', GrpRes),
                get(GrpRes, member, resultado, ResLabel),
                send(ResLabel, selection, LblTxt),

                % 1b. Actualizar estado inline
                get(GrpRes, member, status, StatusLabel),
                send(StatusLabel, selection, EstadoMsg),

                % Ajustar colores según exito/error
                (   sub_atom(EstadoMsg, 0, 5, _, 'Error')
                ->  send(StatusLabel, colour, colour(red)),
                    send(ResLabel, colour, colour(darkgray))
                ;   send(StatusLabel, colour, colour(green)),
                    send(ResLabel, colour, colour(blue))
                ),

                % 2. Agregar al Historial
                get(D, member, 'Historial de Conversiones', GrpHist),
                get(GrpHist, member, historial_lista, ListaHistorial),
                send(ListaHistorial, append, dict_item(HistTxt))
            ;
                get(D, member, 'Resultado y Estado', GrpRes),
                get(GrpRes, member, status, StatusLabel),
                send(StatusLabel, selection, 'No se encontro la tabla para el tipo seleccionado.'),
                send(StatusLabel, colour, colour(red))
            )
        ;
            get(D, member, 'Resultado y Estado', GrpRes),
            get(GrpRes, member, status, StatusLabel),
            send(StatusLabel, selection, 'Por favor, ingresa un offset valido.'),
            send(StatusLabel, colour, colour(red))
        )
    ;
        get(D, member, 'Resultado y Estado', GrpRes),
        get(GrpRes, member, status, StatusLabel),
        send(StatusLabel, selection, 'Por favor, ingresa un numero valido.'),
        send(StatusLabel, colour, colour(red))
    ).

% Parseo defensivo para evitar excepciones con entradas invalidas.
parsear_numero(Texto, Numero) :-
    texto_a_string(Texto, Texto0),
    normalize_space(string(Texto1), Texto0),
    texto_decimal_normalizado(Texto1, TextoNormalizado),
    catch(number_string(Numero, TextoNormalizado), _, fail).

texto_a_string(Texto, Salida) :-
    (   string(Texto)
    ->  Salida = Texto
    ;   atom(Texto)
    ->  atom_string(Texto, Salida)
    ;   catch(get(Texto, value, Val), _, fail)
    ->  texto_a_string(Val, Salida)
    ;   format(string(Salida), '~w', [Texto])
    ).

texto_decimal_normalizado(TextoIn, TextoOut) :-
    string_chars(TextoIn, CharsIn),
    maplist(reemplazar_coma_por_punto, CharsIn, CharsOut),
    string_chars(TextoOut, CharsOut).

reemplazar_coma_por_punto(',', '.') :- !.
reemplazar_coma_por_punto(Char, Char).

% Construye una ruta estable a los archivos de tabla (relativa al .pl).
% Construye una ruta estable a los archivos de tabla (soporta tanto .pl como .exe compilado).
archivo_tabla(Tipo, Archivo) :-
    atomic_list_concat(['tabla_', Tipo, '.txt'], Nombre),
    (   % 1. Si estamos ejecutando un .exe compilado
        current_prolog_flag(os_argv, [ExePath|_]),
        file_directory_name(ExePath, DirExe),
        directory_file_path(DirExe, Nombre, PathExe),
        exists_file(PathExe)
    ->  Archivo = PathExe
    ;   % 2. Si estamos desde el codigo fuente .pl
        source_file(archivo_tabla(_, _), ArchivoFuente),
        file_directory_name(ArchivoFuente, DirPl),
        directory_file_path(DirPl, Nombre, PathPl),
        exists_file(PathPl)
    ->  Archivo = PathPl
    ;   % 3. Fallback: buscar en la carpeta actual
        exists_file(Nombre)
    ->  Archivo = Nombre
    ).

limpiar(D) :-
    % Borrar input
    get(D, member, '2. Entrada de Datos', GrpDatos),
    get(GrpDatos, member, valor, ValItem), send(ValItem, selection, ''),
    get(GrpDatos, member, offset, OffsetItem), send(OffsetItem, selection, '0'),
    % Reiniciar resultado
    get(D, member, 'Resultado y Estado', GrpRes),
    get(GrpRes, member, resultado, ResLabel), send(ResLabel, selection, 'Resultado: --'),
    % Limpiar estado
    get(GrpRes, member, status, StatusLabel), send(StatusLabel, selection, ''),
    % Vaciar historial
    get(D, member, 'Historial de Conversiones', GrpHist),
    get(GrpHist, member, historial_lista, ListaHistorial), send(ListaHistorial, clear).

% ==========================================
% 3. LÓGICA MATEMÁTICA (INTERPOLACIÓN DUAL)
% ==========================================

% --- De Milivoltios a Grados ---
buscar_mv_c(Archivo, V, ResFinal) :-
    csv_read_file(Archivo, Filas0, [separator(0',), convert(true)]),
    % Ordenar filas por milivoltios para evitar saltos en la tabla que
    % producen interpolaciones incorrectas cuando el archivo no está
    % estrictamente ordenado.
    predsort(compare_mv, Filas0, Filas),
    interpolar_mv(Filas, V, ResCalc),
    ResFinal is round(ResCalc * 100) / 100.

interpolar_mv([row(MV1, T1), row(MV2, T2) | _], V, T) :-
    ( (V >= MV1, V =< MV2) ; (V >= MV2, V =< MV1) ), !,
    T is T1 + ((V - MV1) / (MV2 - MV1)) * (T2 - T1).
interpolar_mv([_ | Resto], V, T) :- 
    interpolar_mv(Resto, V, T).

% --- De Grados a Milivoltios ---
buscar_c_mv(Archivo, T_in, ResFinal) :-
    csv_read_file(Archivo, Filas0, [separator(0',), convert(true)]),
    % Ordenar filas por temperatura para interpolar correctamente cuando
    % las entradas no están en orden ascendente/descendente.
    predsort(compare_t, Filas0, Filas),
    interpolar_c(Filas, T_in, ResCalc),
    ResFinal is round(ResCalc * 1000) / 1000. % mV ocupa 3 decimales

interpolar_c([row(MV1, T1), row(MV2, T2) | _], T_in, MV_out) :-
    ( (T_in >= T1, T_in =< T2) ; (T_in >= T2, T_in =< T1) ), !,
    MV_out is MV1 + ((T_in - T1) / (T2 - T1)) * (MV2 - MV1).
interpolar_c([_ | Resto], T_in, MV_out) :- 
    interpolar_c(Resto, T_in, MV_out).

% --- Comparadores para ordenar las filas leidas desde CSV ---
compare_mv(Order, row(MV1,_), row(MV2,_)) :-
    compare(Order, MV1, MV2).

compare_t(Order, row(_,T1), row(_,T2)) :-
    compare(Order, T1, T2).