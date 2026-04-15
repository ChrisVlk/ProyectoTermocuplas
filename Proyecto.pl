:- use_module(library(pce)).
:- use_module(library(csv)).

% ==========================================
% 1. INTERFAZ GRÁFICA (XPCE)
% ==========================================

iniciar_app :-
    % Crear ventana y ajustar tamaño
    new(D, dialog('Conversor de Termocuplas - Academico')),
    send(D, size, size(540, 520)),
    
    % Menús desplegables
    send(D, append, new(TipoMenu, menu(tipo, cycle))),
    send(TipoMenu, append, k),
    send(TipoMenu, append, j),
    send(TipoMenu, append, t),
    
    send(D, append, new(ModoMenu, menu(modo, cycle))),
    send(ModoMenu, append, 'mV a Grados'),
    send(ModoMenu, append, 'Grados a mV'),
    
    % Caja de entrada
    send(D, append, new(ValItem, text_item(valor))),
    send(ValItem, length, 14),
    send(D, append, new(OffsetItem, text_item(offset, '0'))),
    send(OffsetItem, label, 'Offset salida'),
    send(OffsetItem, length, 8),
    
    % Resultado en grande
    send(D, append, new(ResLabel, label(resultado, 'Resultado: --'))),
    send(ResLabel, font, font(helvetica, bold, 18)),

    % Etiqueta de estado inline (reemplaza dialogs inform)
    send(D, append, new(StatusLabel, label(status, ''))),
    send(StatusLabel, font, font(helvetica, normal, 10)),
    
    % Sección de Historial
    send(D, append, label(titulo_historial, 'Historial de Conversiones:')),
    send(D, append, new(Historial, list_browser)),
    send(Historial, name, historial_lista),
    send(Historial, width, 60),
    send(Historial, height, 10), % Muestra hasta 10 líneas a la vez
    
    % Botones
    send(D, append, button(calcular, message(@prolog, calcular, D))),
    send(D, append, button(limpiar, message(@prolog, limpiar, D))),
    send(D, append, button(salir, message(D, destroy))),
    
    % Mostrar ventana
    send(D, open).

% ==========================================
% 2. LÓGICA DE LA INTERFAZ
% ==========================================

calcular(D) :-
    % Obtener datos de la ventana
    get(D, member, tipo, TipoMenu), get(TipoMenu, selection, Tipo),
    get(D, member, modo, ModoMenu), get(ModoMenu, selection, Modo),
    get(D, member, valor, ValItem), get(ValItem, selection, ValText),
    get(D, member, offset, OffsetItem), get(OffsetItem, selection, OffsetText),
    
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
                get(D, member, resultado, ResLabel),
                send(ResLabel, selection, LblTxt),

                % 1b. Actualizar estado inline
                get(D, member, status, StatusLabel),
                send(StatusLabel, selection, EstadoMsg),

                % 2. Agregar al Historial
                get(D, member, historial_lista, ListaHistorial),
                send(ListaHistorial, append, dict_item(HistTxt))
            ;
                get(D, member, status, StatusLabel),
                send(StatusLabel, selection, 'No se encontro la tabla para el tipo seleccionado.')
            )
        ;
            get(D, member, status, StatusLabel),
            send(StatusLabel, selection, 'Por favor, ingresa un offset valido.')
        )
    ;
        get(D, member, status, StatusLabel),
        send(StatusLabel, selection, 'Por favor, ingresa un numero valido.')
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
archivo_tabla(Tipo, Archivo) :-
    atomic_list_concat(['tabla_', Tipo, '.txt'], Nombre),
    source_file(archivo_tabla(_, _), ArchivoFuente),
    file_directory_name(ArchivoFuente, Dir),
    directory_file_path(Dir, Nombre, Archivo),
    exists_file(Archivo).

limpiar(D) :-
    % Borrar input
    get(D, member, valor, ValItem), send(ValItem, selection, ''),
    get(D, member, offset, OffsetItem), send(OffsetItem, selection, '0'),
    % Reiniciar resultado
    get(D, member, resultado, ResLabel), send(ResLabel, selection, 'Resultado: --'),
    % Limpiar estado
    get(D, member, status, StatusLabel), send(StatusLabel, selection, ''),
    % Vaciar historial
    get(D, member, historial_lista, ListaHistorial), send(ListaHistorial, clear).

% ==========================================
% 3. LÓGICA MATEMÁTICA (INTERPOLACIÓN DUAL)
% ==========================================

% --- De Milivoltios a Grados ---
buscar_mv_c(Archivo, V, ResFinal) :-
    csv_read_file(Archivo, Filas, [separator(0',), convert(true)]),
    interpolar_mv(Filas, V, ResCalc),
    ResFinal is round(ResCalc * 100) / 100.

interpolar_mv([row(MV1, T1), row(MV2, T2) | _], V, T) :-
    ( (V >= MV1, V =< MV2) ; (V >= MV2, V =< MV1) ), !,
    T is T1 + ((V - MV1) / (MV2 - MV1)) * (T2 - T1).
interpolar_mv([_ | Resto], V, T) :- 
    interpolar_mv(Resto, V, T).

% --- De Grados a Milivoltios ---
buscar_c_mv(Archivo, T_in, ResFinal) :-
    csv_read_file(Archivo, Filas, [separator(0',), convert(true)]),
    interpolar_c(Filas, T_in, ResCalc),
    ResFinal is round(ResCalc * 1000) / 1000. % mV ocupa 3 decimales

interpolar_c([row(MV1, T1), row(MV2, T2) | _], T_in, MV_out) :-
    ( (T_in >= T1, T_in =< T2) ; (T_in >= T2, T_in =< T1) ), !,
    MV_out is MV1 + ((T_in - T1) / (T2 - T1)) * (MV2 - MV1).
interpolar_c([_ | Resto], T_in, MV_out) :- 
    interpolar_c(Resto, T_in, MV_out).