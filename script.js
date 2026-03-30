const historialConversiones = [];

function maxTempPorTipo(tipo) {
    if (tipo === 'k') return 1372;
    if (tipo === 'j') return 1200;
    return 400;
}

function redondear(valor, decimales) {
    const factor = 10 ** decimales;
    return Math.round(valor * factor) / factor;
}

function formatoNumero(valor, decimales) {
    return redondear(valor, decimales).toFixed(decimales);
}

function pintarTermometro(temp) {
    const liquido = document.getElementById('liquido');
    const bulbo = document.getElementById('bulbo');
    const tipo = document.getElementById('tipo').value;

    let porcentaje = (temp / maxTempPorTipo(tipo)) * 100;
    if (porcentaje < 0) porcentaje = 0;
    if (porcentaje > 100) porcentaje = 100;

    let color = '#3498db';
    if (porcentaje > 30) color = '#f1c40f';
    if (porcentaje > 60) color = '#e67e22';
    if (porcentaje > 85) color = '#e74c3c';

    liquido.style.height = porcentaje + '%';
    liquido.style.backgroundColor = color;
    bulbo.style.backgroundColor = color;
}

function limpiarTermometro() {
    const liquido = document.getElementById('liquido');
    const bulbo = document.getElementById('bulbo');
    liquido.style.height = '0%';
    bulbo.style.backgroundColor = '#bdc3c7';
}

function estadoClase(estado) {
    if (estado === 'normal') return 'estado-normal';
    if (estado === 'advertencia') return 'estado-advertencia';
    if (estado === 'peligro') return 'estado-peligro';
    return 'estado-neutral';
}

function capitalizar(texto) {
    if (!texto) return '';
    return texto.charAt(0).toUpperCase() + texto.slice(1);
}

function actualizarEstado(estado, mensaje) {
    const badge = document.getElementById('estado-badge');
    const texto = document.getElementById('estado-texto');

    badge.className = `estado-badge ${estadoClase(estado)}`;
    badge.innerText = capitalizar(estado || 'neutral');
    texto.innerText = mensaje || 'Sin informacion de estado.';
}

function limpiarComparador() {
    const body = document.getElementById('comparacion-body');
    body.innerHTML = '<tr><td colspan="3">Aun sin datos para comparar.</td></tr>';
}

function renderComparador(filas, modo, offset) {
    const body = document.getElementById('comparacion-body');
    const decimales = modo === 'mv_a_temp' ? 2 : 3;
    const unidad = modo === 'mv_a_temp' ? '°C' : 'mV';

    body.innerHTML = '';
    filas.forEach((fila) => {
        const tr = document.createElement('tr');

        if (fila.status === 'success') {
            const valor = parseFloat(fila.resultado) + offset;
            tr.innerHTML = `
                <td>${fila.tipo}</td>
                <td>${formatoNumero(valor, decimales)} ${unidad}</td>
                <td><span class="estado-badge ${estadoClase(fila.estado)}">${capitalizar(fila.estado)}</span></td>
            `;
        } else {
            tr.innerHTML = `
                <td>${fila.tipo}</td>
                <td>--</td>
                <td>${fila.mensaje || 'Sin datos'}</td>
            `;
        }

        body.appendChild(tr);
    });
}

function renderHistorial() {
    const lista = document.getElementById('historial-lista');
    if (historialConversiones.length === 0) {
        lista.innerHTML = '<li>Sin conversiones registradas.</li>';
        return;
    }

    lista.innerHTML = '';
    historialConversiones.forEach((item) => {
        const li = document.createElement('li');
        li.innerText = `[${item.hora}] ${item.tipo.toUpperCase()} | ${item.modo} | ${item.entrada} -> ${item.salida} (${item.estado})`;
        lista.appendChild(li);
    });
}

function agregarHistorial({ tipo, modo, entrada, salida, estado }) {
    const hora = new Date().toLocaleTimeString();
    historialConversiones.unshift({ tipo, modo, entrada, salida, estado, hora });
    if (historialConversiones.length > 10) {
        historialConversiones.pop();
    }
    renderHistorial();
}

function actualizarModo() {
    const modo = document.getElementById('modo').value;
    const entradaLabel = document.getElementById('entrada-label');
    const entrada = document.getElementById('entrada');
    const offsetLabel = document.getElementById('offset-label');
    const offset = document.getElementById('offset');
    const resultadoUnidad = document.getElementById('resultado-unidad');
    const resultadoValor = document.getElementById('temp-valor');
    const errorMsg = document.getElementById('error-msg');
    const ajusteInfo = document.getElementById('ajuste-info');

    if (modo === 'mv_a_temp') {
        entradaLabel.innerText = 'Milivoltios (mV)';
        entrada.placeholder = 'Ej: 0.039';
        offsetLabel.innerText = 'Offset de calibracion (°C)';
        resultadoUnidad.innerText = '°C';
    } else {
        entradaLabel.innerText = 'Temperatura (°C)';
        entrada.placeholder = 'Ej: 250';
        offsetLabel.innerText = 'Offset de calibracion (mV)';
        resultadoUnidad.innerText = 'mV';
    }

    entrada.value = '';
    offset.value = '0';
    resultadoValor.innerText = '--';
    resultadoValor.style.color = '#f4fbff';
    errorMsg.innerText = '';
    ajusteInfo.innerText = '';
    actualizarEstado('neutral', 'Realiza una conversion para ver el estado termico.');
    limpiarTermometro();
    limpiarComparador();
}

async function cargarComparador(modo, valorEntrada, offset) {
    const respuesta = await fetch(`/api/comparar?modo=${encodeURIComponent(modo)}&valor=${encodeURIComponent(valorEntrada)}`);
    if (!respuesta.ok) {
        throw new Error(`HTTP ${respuesta.status}`);
    }

    const datos = await respuesta.json();
    if (datos.status === 'success' && Array.isArray(datos.comparacion)) {
        renderComparador(datos.comparacion, modo, offset);
    } else {
        limpiarComparador();
    }
}

async function ejecutarConversion() {
    const modo = document.getElementById('modo').value;
    const tipo = document.getElementById('tipo').value;
    const entrada = document.getElementById('entrada').value.trim();
    const offset = Number(document.getElementById('offset').value || 0);
    const resultadoValor = document.getElementById('temp-valor');
    const errorMsg = document.getElementById('error-msg');
    const ajusteInfo = document.getElementById('ajuste-info');

    if (entrada === '' || Number.isNaN(Number(entrada))) {
        alert('Por favor, ingresa un valor numerico valido.');
        return;
    }

    const entradaNumero = Number(entrada);

    try {
        const url = modo === 'mv_a_temp'
            ? `/api/temperatura?tipo=${encodeURIComponent(tipo)}&mv=${encodeURIComponent(entrada)}`
            : `/api/milivoltios?tipo=${encodeURIComponent(tipo)}&temperatura=${encodeURIComponent(entrada)}`;

        const respuesta = await fetch(url);
        if (!respuesta.ok) {
            throw new Error(`HTTP ${respuesta.status}`);
        }

        const datos = await respuesta.json();

        if (datos.status === 'success') {
            const decimales = modo === 'mv_a_temp' ? 2 : 3;
            const base = modo === 'mv_a_temp' ? parseFloat(datos.temperatura) : parseFloat(datos.milivoltios);
            const ajustado = base + offset;

            resultadoValor.innerText = formatoNumero(ajustado, decimales);
            resultadoValor.style.color = '#f4fbff';
            errorMsg.innerText = '';
            actualizarEstado(datos.estado, datos.mensaje_estado);

            if (offset !== 0) {
                ajusteInfo.innerText = `Ajuste aplicado: ${offset > 0 ? '+' : ''}${offset} ${modo === 'mv_a_temp' ? '°C' : 'mV'}`;
            } else {
                ajusteInfo.innerText = '';
            }

            if (modo === 'mv_a_temp') {
                pintarTermometro(ajustado);
            } else {
                pintarTermometro(entradaNumero);
            }

            await cargarComparador(modo, entradaNumero, offset);

            agregarHistorial({
                tipo,
                modo,
                entrada: `${entradaNumero} ${modo === 'mv_a_temp' ? 'mV' : '°C'}`,
                salida: `${formatoNumero(ajustado, decimales)} ${modo === 'mv_a_temp' ? '°C' : 'mV'}`,
                estado: capitalizar(datos.estado)
            });
        } else {
            resultadoValor.innerText = '--';
            resultadoValor.style.color = '#f4fbff';
            errorMsg.innerText = datos.mensaje || 'No se pudo realizar la conversion.';
            ajusteInfo.innerText = '';
            actualizarEstado('neutral', 'Sin estado por conversion fallida.');
            limpiarTermometro();
            limpiarComparador();
        }
    } catch (error) {
        resultadoValor.innerText = '--';
        resultadoValor.style.color = '#f4fbff';
        errorMsg.innerText = 'Error al conectar con el servidor Prolog.';
        ajusteInfo.innerText = '';
        actualizarEstado('neutral', 'No se pudo obtener estado por error de conexion.');
        limpiarTermometro();
        limpiarComparador();
        console.error('Error:', error);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    actualizarModo();
    const entrada = document.getElementById('entrada');
    entrada.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') {
            ejecutarConversion();
        }
    });
});