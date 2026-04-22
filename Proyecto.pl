:- use_module(library(pce)).
:- use_module(library(csv)).

iniciar_app :-
    new(Ventana, dialog('Conversor de Termocuplas')),
    send(Ventana, size, size(560, 680)),
    send(Ventana, append, new(Titulo, label(titulo_principal, 'Calculadora de Termocuplas'))),
    send(Titulo, font, font(helvetica, bold, 18)),
    
    send(Ventana, append, new(GrupoConfig, dialog_group('1. Configuracion del Sensor', box))),
    send(GrupoConfig, append, new(MenuTipo, menu(tipo, cycle))),
    send(MenuTipo, append, k),
    send(MenuTipo, append, j),
    send(MenuTipo, append, t),
    send(MenuTipo, selection, k),
    send(GrupoConfig, append, new(MenuModo, menu(modo, cycle)), right),
    send(MenuModo, append, 'mV a Grados'),
    send(MenuModo, append, 'Grados a mV'),
    send(MenuModo, selection, 'mV a Grados'),
    
    send(Ventana, append, new(GrupoDatos, dialog_group('2. Entrada de Datos', box))),
    send(GrupoDatos, append, new(InputValor, text_item(valor))),
    send(InputValor, length, 14),
    send(InputValor, selection, '0'),
    send(GrupoDatos, append, new(InputOffset, text_item(offset, '0')), right),
    send(InputOffset, label, 'Offset '),
    send(InputOffset, length, 8),
    
    send(Ventana, append, new(GrupoResultado, dialog_group('Resultado y Estado', box))),
    send(GrupoResultado, append, new(EtiquetaResultado, label(resultado, 'Resultado: --'))),
    send(EtiquetaResultado, font, font(helvetica, bold, 24)),
    send(EtiquetaResultado, colour, colour(blue)),
    send(GrupoResultado, append, new(EtiquetaEstado, label(status, ''))),
    send(EtiquetaEstado, font, font(helvetica, italic, 11)),
    send(EtiquetaEstado, colour, colour(gray)),
    
    send(Ventana, append, new(BotonCalcular, button('  CALCULAR  ', message(@prolog, calcular, Ventana)))),
    send(BotonCalcular, font, font(helvetica, bold, 14)),
    send(Ventana, append, new(_BotonLimpiar, button('Limpiar', message(@prolog, limpiar, Ventana))), right),
    
    send(Ventana, append, new(GrupoHistorial, dialog_group('Historial de Conversiones', box))),
    send(GrupoHistorial, append, new(CajaHistorial, list_browser)),
    send(CajaHistorial, name, historial_lista),
    send(CajaHistorial, width, 65),
    send(CajaHistorial, height, 8),
    send(CajaHistorial, font, font(helvetica, normal, 10)),
    
    send(Ventana, append, new(_BotonSalir, button('Salir', message(Ventana, return, ok)))),
    get(Ventana, confirm_centered, _),
    free(Ventana).

calcular(Ventana) :-
    get(Ventana, member, '1. Configuracion del Sensor', GrupoConfig),
    get(GrupoConfig, member, tipo, MenuTipo), get(MenuTipo, selection, Tipo),
    get(GrupoConfig, member, modo, MenuModo), get(MenuModo, selection, Modo),
    get(Ventana, member, '2. Entrada de Datos', GrupoDatos),
    get(GrupoDatos, member, valor, InputValor), get(InputValor, selection, ValorTexto),
    get(GrupoDatos, member, offset, InputOffset), get(InputOffset, selection, OffsetTexto),
    validar_y_calcular(Ventana, Tipo, Modo, ValorTexto, OffsetTexto).

validar_y_calcular(Ventana, Tipo, Modo, ValorTexto, OffsetTexto) :-
    parsear_numero(ValorTexto, ValorNumerico), !,
    validar_offset(Ventana, Tipo, Modo, ValorNumerico, OffsetTexto).
validar_y_calcular(Ventana, _, _, _, _) :-
    mostrar_error(Ventana, 'Por favor, ingresa un numero valido.').

validar_offset(Ventana, Tipo, Modo, ValorNumerico, OffsetTexto) :-
    parsear_numero(OffsetTexto, Offset), !,
    validar_archivo(Ventana, Tipo, Modo, ValorNumerico, Offset).
validar_offset(Ventana, _, _, _, _) :-
    mostrar_error(Ventana, 'Por favor, ingresa un offset valido.').

validar_archivo(Ventana, Tipo, Modo, ValorNumerico, Offset) :-
    archivo_tabla(Tipo, RutaTabla), !,
    ejecutar_modo(Ventana, RutaTabla, Tipo, Modo, ValorNumerico, Offset).
validar_archivo(Ventana, _, _, _, _) :-
    mostrar_error(Ventana, 'No se encontro la tabla para el tipo seleccionado.').

ejecutar_modo(Ventana, RutaTabla, Tipo, 'mV a Grados', ValorNumerico, Offset) :-
    !, calcular_mv_a_c(Ventana, RutaTabla, Tipo, ValorNumerico, Offset).
ejecutar_modo(Ventana, RutaTabla, Tipo, _, ValorNumerico, Offset) :-
    calcular_c_a_mv(Ventana, RutaTabla, Tipo, ValorNumerico, Offset).

calcular_mv_a_c(Ventana, RutaTabla, Tipo, ValorNumerico, Offset) :-
    buscar_mv_c(RutaTabla, ValorNumerico, ResultadoBase), !,
    ResultadoFinal is round((ResultadoBase + Offset) * 100) / 100,
    atomic_list_concat(['Resultado: ', ResultadoFinal, ' C'], TextoEtiqueta),
    atomic_list_concat(['[Tipo ', Tipo, '] ', ValorNumerico, ' mV  =  ', ResultadoFinal, ' C (offset ', Offset, ')'], TextoHistorial),
    mostrar_exito(Ventana, TextoEtiqueta, TextoHistorial, 'Conversion correcta.:)').
calcular_mv_a_c(Ventana, _, _, _, _) :-
    mostrar_error_rango(Ventana).

calcular_c_a_mv(Ventana, RutaTabla, Tipo, ValorNumerico, Offset) :-
    buscar_c_mv(RutaTabla, ValorNumerico, ResultadoBase), !,
    ResultadoFinal is round((ResultadoBase + Offset) * 1000) / 1000,
    atomic_list_concat(['Resultado: ', ResultadoFinal, ' mV'], TextoEtiqueta),
    atomic_list_concat(['[Tipo ', Tipo, '] ', ValorNumerico, ' C  =  ', ResultadoFinal, ' mV (offset ', Offset, ')'], TextoHistorial),
    mostrar_exito(Ventana, TextoEtiqueta, TextoHistorial, 'Conversion correcta.').
calcular_c_a_mv(Ventana, _, _, _, _) :-
    mostrar_error_rango(Ventana).

mostrar_error(Ventana, Mensaje) :-
    get(Ventana, member, 'Resultado y Estado', GrupoResultado),
    get(GrupoResultado, member, status, EtiquetaEstado),
    send(EtiquetaEstado, selection, Mensaje),
    send(EtiquetaEstado, colour, colour(red)).

mostrar_error_rango(Ventana) :-
    get(Ventana, member, 'Resultado y Estado', GrupoResultado),
    get(GrupoResultado, member, resultado, EtiquetaResultado),
    send(EtiquetaResultado, selection, 'Error: Fuera de rango'),
    send(EtiquetaResultado, colour, colour(darkgray)),
    get(GrupoResultado, member, status, EtiquetaEstado),
    send(EtiquetaEstado, selection, 'Error: fuera de rango'),
    send(EtiquetaEstado, colour, colour(red)),
    get(Ventana, member, 'Historial de Conversiones', GrupoHistorial),
    get(GrupoHistorial, member, historial_lista, CajaHistorial),
    send(CajaHistorial, append, dict_item('Error: Valor fuera de limites')).

mostrar_exito(Ventana, TextoEtiqueta, TextoHistorial, MensajeEstado) :-
    get(Ventana, member, 'Resultado y Estado', GrupoResultado),
    get(GrupoResultado, member, resultado, EtiquetaResultado),
    send(EtiquetaResultado, selection, TextoEtiqueta),
    send(EtiquetaResultado, colour, colour(blue)),
    get(GrupoResultado, member, status, EtiquetaEstado),
    send(EtiquetaEstado, selection, MensajeEstado),
    send(EtiquetaEstado, colour, colour(green)),
    get(Ventana, member, 'Historial de Conversiones', GrupoHistorial),
    get(GrupoHistorial, member, historial_lista, CajaHistorial),
    send(CajaHistorial, append, dict_item(TextoHistorial)).

parsear_numero(Texto, Numero) :-
    texto_a_string(Texto, TextoS),
    normalize_space(string(TextoN), TextoS),
    texto_decimal_normalizado(TextoN, TextoNormalizado),
    catch(number_string(Numero, TextoNormalizado), _, fail).

texto_a_string(Texto, Salida) :-
    string(Texto), !, Salida = Texto.
texto_a_string(Texto, Salida) :-
    atom(Texto), !, atom_string(Texto, Salida).
texto_a_string(Texto, Salida) :-
    catch(get(Texto, value, Valor), _, fail), !, texto_a_string(Valor, Salida).
texto_a_string(Texto, Salida) :-
    format(string(Salida), '~w', [Texto]).

texto_decimal_normalizado(TextoIn, TextoOut) :-
    string_chars(TextoIn, CaracteresIn),
    maplist(reemplazar_coma_por_punto, CaracteresIn, CaracteresOut),
    string_chars(TextoOut, CaracteresOut).

reemplazar_coma_por_punto(',', '.') :- !.
reemplazar_coma_por_punto(Char, Char).

archivo_tabla(Tipo, RutaTabla) :-
    atomic_list_concat(['tabla_', Tipo, '.txt'], NombreArchivo),
    buscar_archivo(NombreArchivo, RutaTabla).

buscar_archivo(NombreArchivo, RutaFinal) :-
    current_prolog_flag(os_argv, [RutaExe|_]),
    file_directory_name(RutaExe, DirectorioExe),
    directory_file_path(DirectorioExe, NombreArchivo, RutaCompletaExe),
    exists_file(RutaCompletaExe), !,
    RutaFinal = RutaCompletaExe.
buscar_archivo(NombreArchivo, RutaFinal) :-
    source_file(archivo_tabla(_, _), ArchivoFuente),
    file_directory_name(ArchivoFuente, DirectorioPl),
    directory_file_path(DirectorioPl, NombreArchivo, RutaCompletaPl),
    exists_file(RutaCompletaPl), !,
    RutaFinal = RutaCompletaPl.
buscar_archivo(NombreArchivo, RutaFinal) :-
    exists_file(NombreArchivo), !,
    RutaFinal = NombreArchivo.

limpiar(Ventana) :-
    get(Ventana, member, '2. Entrada de Datos', GrupoEntrada),
    get(GrupoEntrada, member, valor, InputValor), send(InputValor, selection, ''),
    get(GrupoEntrada, member, offset, InputOffset), send(InputOffset, selection, '0'),
    get(Ventana, member, 'Resultado y Estado', GrupoResultado),
    get(GrupoResultado, member, resultado, EtiquetaResultado), send(EtiquetaResultado, selection, 'Resultado: --'),
    get(GrupoResultado, member, status, EtiquetaEstado), send(EtiquetaEstado, selection, ''),
    get(Ventana, member, 'Historial de Conversiones', GrupoHistorial),
    get(GrupoHistorial, member, historial_lista, CajaHistorial), send(CajaHistorial, clear).

buscar_mv_c(RutaTabla, Voltaje, ResultadoFinal) :-
    csv_read_file(RutaTabla, DatosBrutos, [separator(44), convert(true)]),
    predsort(comparar_por_mv, DatosBrutos, DatosOrdenados),
    interpolar_mv(DatosOrdenados, Voltaje, ValorCalculado),
    ResultadoFinal is round(ValorCalculado * 100) / 100.

interpolar_mv([row(MV_A, Temp_A), row(MV_B, Temp_B) | _], Voltaje, Temperatura) :-
    ( (Voltaje >= MV_A, Voltaje =< MV_B) ; (Voltaje >= MV_B, Voltaje =< MV_A) ), !,
    Temperatura is Temp_A + ((Voltaje - MV_A) / (MV_B - MV_A)) * (Temp_B - Temp_A).
interpolar_mv([_ | RestoDatos], Voltaje, Temperatura) :- 
    interpolar_mv(RestoDatos, Voltaje, Temperatura).

buscar_c_mv(RutaTabla, TempEntrada, ResultadoFinal) :-
    csv_read_file(RutaTabla, DatosBrutos, [separator(44), convert(true)]),
    predsort(comparar_por_temp, DatosBrutos, DatosOrdenados),
    interpolar_c(DatosOrdenados, TempEntrada, ValorCalculado),
    ResultadoFinal is round(ValorCalculado * 1000) / 1000.

interpolar_c([row(MV_A, Temp_A), row(MV_B, Temp_B) | _], TempEntrada, MVSalida) :-
    ( (TempEntrada >= Temp_A, TempEntrada =< Temp_B) ; (TempEntrada >= Temp_B, TempEntrada =< Temp_A) ), !,
    MVSalida is MV_A + ((TempEntrada - Temp_A) / (Temp_B - Temp_A)) * (MV_B - MV_A).
interpolar_c([_ | RestoDatos], TempEntrada, MVSalida) :- 
    interpolar_c(RestoDatos, TempEntrada, MVSalida).

comparar_por_mv(Orden, row(MV_A,_), row(MV_B,_)) :-
    compare(Orden, MV_A, MV_B).

comparar_por_temp(Orden, row(_,Temp_A), row(_,Temp_B)) :-
    compare(Orden, Temp_A, Temp_B).