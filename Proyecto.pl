:- use_module(library(pce)).
:- use_module(library(csv)).

iniciar_app :-
    new(D, dialog('Conversor de Termocuplas')),
    send(D, size, size(560, 680)),
    send(D, append, new(Tit, label(titulo_principal, 'Calculadora de Termocuplas'))),
    send(Tit, font, font(helvetica, bold, 18)),
    send(D, append, new(GrpConfig, dialog_group('1. Configuracion del Sensor', box))),
    send(GrpConfig, append, new(TipoMenu, menu(tipo, cycle))),
    send(TipoMenu, append, k),
    send(TipoMenu, append, j),
    send(TipoMenu, append, t),
    send(TipoMenu, selection, k),
    send(GrpConfig, append, new(ModoMenu, menu(modo, cycle)), right),
    send(ModoMenu, append, 'mV a Grados'),
    send(ModoMenu, append, 'Grados a mV'),
    send(ModoMenu, selection, 'mV a Grados'),
    send(D, append, new(GrpDatos, dialog_group('2. Entrada de Datos', box))),
    send(GrpDatos, append, new(ValItem, text_item(valor))),
    send(ValItem, length, 14),
    send(ValItem, selection, '0'),
    send(GrpDatos, append, new(OffsetItem, text_item(offset, '0')), right),
    send(OffsetItem, label, 'Offset '),
    send(OffsetItem, length, 8),
    send(D, append, new(GrpRes, dialog_group('Resultado y Estado', box))),
    send(GrpRes, append, new(ResLabel, label(resultado, 'Resultado: --'))),
    send(ResLabel, font, font(helvetica, bold, 24)),
    send(ResLabel, colour, colour(blue)),
    send(GrpRes, append, new(StatusLabel, label(status, ''))),
    send(StatusLabel, font, font(helvetica, italic, 11)),
    send(StatusLabel, colour, colour(gray)),
    send(D, append, new(CalcBtn, button('  CALCULAR  ', message(@prolog, calcular, D)))),
    send(CalcBtn, font, font(helvetica, bold, 14)),
    send(D, append, new(_ClearBtn, button('Limpiar', message(@prolog, limpiar, D))), right),
    send(D, append, new(GrpHist, dialog_group('Historial de Conversiones', box))),
    send(GrpHist, append, new(Historial, list_browser)),
    send(Historial, name, historial_lista),
    send(Historial, width, 65),
    send(Historial, height, 8),
    send(Historial, font, font(helvetica, normal, 10)),
    send(D, append, new(_ExitBtn, button('Salir', message(D, return, ok)))),
    get(D, confirm_centered, _),
    free(D).

calcular(D) :-
    get(D, member, '1. Configuracion del Sensor', GrpConfig),
    get(GrpConfig, member, tipo, TipoMenu), get(TipoMenu, selection, Tipo),
    get(GrpConfig, member, modo, ModoMenu), get(ModoMenu, selection, Modo),
    get(D, member, '2. Entrada de Datos', GrpDatos),
    get(GrpDatos, member, valor, ValItem), get(ValItem, selection, ValText),
    get(GrpDatos, member, offset, OffsetItem), get(OffsetItem, selection, OffsetText),
    validar_y_calcular(D, Tipo, Modo, ValText, OffsetText).

validar_y_calcular(D, Tipo, Modo, ValText, OffsetText) :-
    parsear_numero(ValText, ValNum), !,
    validar_offset(D, Tipo, Modo, ValNum, OffsetText).
validar_y_calcular(D, _, _, _, _) :-
    mostrar_error(D, 'Por favor, ingresa un numero valido.').

validar_offset(D, Tipo, Modo, ValNum, OffsetText) :-
    parsear_numero(OffsetText, Offset), !,
    validar_archivo(D, Tipo, Modo, ValNum, Offset).
validar_offset(D, _, _, _, _) :-
    mostrar_error(D, 'Por favor, ingresa un offset valido.').

validar_archivo(D, Tipo, Modo, ValNum, Offset) :-
    archivo_tabla(Tipo, Archivo), !,
    ejecutar_modo(D, Archivo, Tipo, Modo, ValNum, Offset).
validar_archivo(D, _, _, _, _) :-
    mostrar_error(D, 'No se encontro la tabla para el tipo seleccionado.').

ejecutar_modo(D, Archivo, Tipo, 'mV a Grados', ValNum, Offset) :-
    !, calcular_mv_c(D, Archivo, Tipo, ValNum, Offset).
ejecutar_modo(D, Archivo, Tipo, _, ValNum, Offset) :-
    calcular_c_mv(D, Archivo, Tipo, ValNum, Offset).

calcular_mv_c(D, Archivo, Tipo, ValNum, Offset) :-
    buscar_mv_c(Archivo, ValNum, ResBase), !,
    Res is round((ResBase + Offset) * 100) / 100,
    atomic_list_concat(['Resultado: ', Res, ' C'], LblTxt),
    atomic_list_concat(['[Tipo ', Tipo, '] ', ValNum, ' mV  =  ', Res, ' C (offset ', Offset, ')'], HistTxt),
    mostrar_exito(D, LblTxt, HistTxt, 'Conversion correcta.:)').
calcular_mv_c(D, _, _, _, _) :-
    mostrar_error_rango(D).

calcular_c_mv(D, Archivo, Tipo, ValNum, Offset) :-
    buscar_c_mv(Archivo, ValNum, ResBase), !,
    Res is round((ResBase + Offset) * 1000) / 1000,
    atomic_list_concat(['Resultado: ', Res, ' mV'], LblTxt),
    atomic_list_concat(['[Tipo ', Tipo, '] ', ValNum, ' C  =  ', Res, ' mV (offset ', Offset, ')'], HistTxt),
    mostrar_exito(D, LblTxt, HistTxt, 'Conversion correcta.').
calcular_c_mv(D, _, _, _, _) :-
    mostrar_error_rango(D).

mostrar_error(D, Msg) :-
    get(D, member, 'Resultado y Estado', GrpRes),
    get(GrpRes, member, status, StatusLabel),
    send(StatusLabel, selection, Msg),
    send(StatusLabel, colour, colour(red)).

mostrar_error_rango(D) :-
    get(D, member, 'Resultado y Estado', GrpRes),
    get(GrpRes, member, resultado, ResLabel),
    send(ResLabel, selection, 'Error: Fuera de rango'),
    send(ResLabel, colour, colour(darkgray)),
    get(GrpRes, member, status, StatusLabel),
    send(StatusLabel, selection, 'Error: fuera de rango'),
    send(StatusLabel, colour, colour(red)),
    get(D, member, 'Historial de Conversiones', GrpHist),
    get(GrpHist, member, historial_lista, ListaHistorial),
    send(ListaHistorial, append, dict_item('Error: Valor fuera de limites')).

mostrar_exito(D, LblTxt, HistTxt, EstadoMsg) :-
    get(D, member, 'Resultado y Estado', GrpRes),
    get(GrpRes, member, resultado, ResLabel),
    send(ResLabel, selection, LblTxt),
    send(ResLabel, colour, colour(blue)),
    get(GrpRes, member, status, StatusLabel),
    send(StatusLabel, selection, EstadoMsg),
    send(StatusLabel, colour, colour(green)),
    get(D, member, 'Historial de Conversiones', GrpHist),
    get(GrpHist, member, historial_lista, ListaHistorial),
    send(ListaHistorial, append, dict_item(HistTxt)).

parsear_numero(Texto, Numero) :-
    texto_a_string(Texto, Texto0),
    normalize_space(string(Texto1), Texto0),
    texto_decimal_normalizado(Texto1, TextoNormalizado),
    catch(number_string(Numero, TextoNormalizado), _, fail).

texto_a_string(Texto, Salida) :-
    string(Texto), !, Salida = Texto.
texto_a_string(Texto, Salida) :-
    atom(Texto), !, atom_string(Texto, Salida).
texto_a_string(Texto, Salida) :-
    catch(get(Texto, value, Val), _, fail), !, texto_a_string(Val, Salida).
texto_a_string(Texto, Salida) :-
    format(string(Salida), '~w', [Texto]).

texto_decimal_normalizado(TextoIn, TextoOut) :-
    string_chars(TextoIn, CharsIn),
    maplist(reemplazar_coma_por_punto, CharsIn, CharsOut),
    string_chars(TextoOut, CharsOut).

reemplazar_coma_por_punto(',', '.') :- !.
reemplazar_coma_por_punto(Char, Char).

archivo_tabla(Tipo, Archivo) :-
    atomic_list_concat(['tabla_', Tipo, '.txt'], Nombre),
    buscar_archivo(Nombre, Archivo).

buscar_archivo(Nombre, Archivo) :-
    current_prolog_flag(os_argv, [ExePath|_]),
    file_directory_name(ExePath, DirExe),
    directory_file_path(DirExe, Nombre, PathExe),
    exists_file(PathExe), !,
    Archivo = PathExe.
buscar_archivo(Nombre, Archivo) :-
    source_file(archivo_tabla(_, _), ArchivoFuente),
    file_directory_name(ArchivoFuente, DirPl),
    directory_file_path(DirPl, Nombre, PathPl),
    exists_file(PathPl), !,
    Archivo = PathPl.
buscar_archivo(Nombre, Archivo) :-
    exists_file(Nombre), !,
    Archivo = Nombre.

limpiar(D) :-
    get(D, member, '2. Entrada de Datos', GrpDatos),
    get(GrpDatos, member, valor, ValItem), send(ValItem, selection, ''),
    get(GrpDatos, member, offset, OffsetItem), send(OffsetItem, selection, '0'),
    get(D, member, 'Resultado y Estado', GrpRes),
    get(GrpRes, member, resultado, ResLabel), send(ResLabel, selection, 'Resultado: --'),
    get(GrpRes, member, status, StatusLabel), send(StatusLabel, selection, ''),
    get(D, member, 'Historial de Conversiones', GrpHist),
    get(GrpHist, member, historial_lista, ListaHistorial), send(ListaHistorial, clear).

buscar_mv_c(Archivo, V, ResFinal) :-
    csv_read_file(Archivo, Filas0, [separator(44), convert(true)]),
    predsort(compare_mv, Filas0, Filas),
    interpolar_mv(Filas, V, ResCalc),
    ResFinal is round(ResCalc * 100) / 100.

interpolar_mv([row(MV1, T1), row(MV2, T2) | _], V, T) :-
    ( (V >= MV1, V =< MV2) ; (V >= MV2, V =< MV1) ), !,
    T is T1 + ((V - MV1) / (MV2 - MV1)) * (T2 - T1).
interpolar_mv([_ | Resto], V, T) :- 
    interpolar_mv(Resto, V, T).

buscar_c_mv(Archivo, T_in, ResFinal) :-
    csv_read_file(Archivo, Filas0, [separator(44), convert(true)]),
    predsort(compare_t, Filas0, Filas),
    interpolar_c(Filas, T_in, ResCalc),
    ResFinal is round(ResCalc * 1000) / 1000.

interpolar_c([row(MV1, T1), row(MV2, T2) | _], T_in, MV_out) :-
    ( (T_in >= T1, T_in =< T2) ; (T_in >= T2, T_in =< T1) ), !,
    MV_out is MV1 + ((T_in - T1) / (T2 - T1)) * (MV2 - MV1).
interpolar_c([_ | Resto], T_in, MV_out) :- 
    interpolar_c(Resto, T_in, MV_out).

compare_mv(Order, row(MV1,_), row(MV2,_)) :-
    compare(Order, MV1, MV2).

compare_t(Order, row(_,T1), row(_,T2)) :-
    compare(Order, T1, T2).