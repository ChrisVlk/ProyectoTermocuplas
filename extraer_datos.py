import pdfplumber
import os

def extraer_termocupla(archivo_pdf, archivo_txt):
    if not os.path.exists(archivo_pdf):
        print(f"❌ No se encontró el archivo: {archivo_pdf}")
        return

    datos_formateados = []

    print(f"Procesando {archivo_pdf}...")
    
    with pdfplumber.open(archivo_pdf) as pdf:
        for pagina in pdf.pages:
            texto = pagina.extract_text()
            if not texto:
                continue
            
            lineas = texto.split('\n')
            for linea in lineas:
                # Separar la línea por espacios
                partes = linea.strip().split()
                
                # Las filas de datos válidas suelen tener al menos 11 columnas
                # (Temp Base, +0, +1, +2, +3, +4, +5, +6, +7, +8, +9)
                if len(partes) >= 11:
                    try:
                        # Intentamos convertir la primera columna a entero (Temperatura Base)
                        temp_base = int(partes[0])
                        
                        # Recorremos las siguientes 10 columnas (del +0 al +9)
                        for i in range(10):
                            mv_str = partes[i + 1]
                            
                            # Ignorar guiones o celdas vacías (pasa en temperaturas extremas)
                            if mv_str not in ['-', '', '.']:
                                # Convertimos el texto a número decimal
                                mv = float(mv_str)
                                temp_actual = temp_base + i
                                
                                # Guardamos en formato Prolog: milivoltios,temperatura
                                datos_formateados.append(f"{mv},{temp_actual}")
                                
                    except ValueError:
                        # Si la primera columna no es un número (ej. encabezados "°C"), la ignoramos
                        continue

    # Guardar los datos en el archivo .txt
    with open(archivo_txt, 'w', encoding='utf-8') as f:
        f.write('\n'.join(datos_formateados))
    
    print(f"✅ ¡Éxito! {len(datos_formateados)} valores guardados en {archivo_txt}\n")

# Nombres de tus archivos PDF (asegúrate de que se llamen exactamente así)
pdfs = [
    ("Type_K_Thermocouple_Reference_Table.pdf", "tabla_k.txt"),
    ("Type_J_Thermocouple_Reference_Table.pdf", "tabla_j.txt"),
    ("Type_T_Thermocouple_Reference_Table.pdf", "tabla_t.txt")
]

# Ejecutar la extracción para cada archivo
for pdf, txt in pdfs:
    extraer_termocupla(pdf, txt)

print("🎉 Extracción finalizada. Ya puedes usar los .txt en tu servidor Prolog.")