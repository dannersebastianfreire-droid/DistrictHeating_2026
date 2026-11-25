# Heat Supply + Storage: salida HeatPort del depósito y revisión de ensayos

Modelo: `CicleGas2.mo` (esta carpeta). OpenModelica 1.27.1, MSL 4.1.0 (compatible con la 4.0.0 que pide el archivo).
Fecha de los ensayos: 23/11/2026. Los parámetros son los del modelo actual, sin redimensionar.

Datos horarios del ensayo principal: [resultados/CentralHeatPort_horario.csv](resultados/CentralHeatPort_horario.csv) (separador `;`, 73 filas de 0 a 72 h).

---

## 1. Estado de los modelos

| Modelo | Qué prueba | Resultado |
|---|---|---|
| `TestDiposit` | Depósito solo: carga, reposo y descarga por fluido | OK |
| `CicloCombinadoDeposito` | Central + depósito + torre, sin demanda (24 h, depósito a 70 °C) | OK |
| `EnsayoDepositoFrio` / `EnsayoDepositoLleno` | Lo mismo con el depósito a 50 °C / 90 °C | OK |
| `EnsayoPotencia125` | Potencia al 125 % | OK |
| `CentralCompleta` | Entorno de testing anterior (válvula de 3 vías + edificio por fluido) | **Antes fallaba a 0,3 s; ahora OK** |
| `TestDepositoHeatPort_Q` (nuevo) | Depósito solo; el consumidor impone **Q** por el HeatPort | OK |
| `TestDepositoHeatPort_T` (nuevo) | Depósito solo; el consumidor impone **T** por el HeatPort | OK |
| `CentralHeatPort` (nuevo) | Central + depósito + torre + demanda inventada por el HeatPort (72 h) | OK |

### Cambios hechos en el modelo
1. **`EnergyUseMonitor`**: `P_storage_useful` ya no se calcula con `der(E_tank_useful)`. Esa derivada de una expresión algebraica con `min`/`max` obligaba a derivar todo el sistema hidráulico, y era lo que hacía fallar `CentralCompleta`. Ahora la calcula el depósito.
2. **`StratifiedTank`**:
   - Variables nuevas `E_capacity`, `E_useful` y `P_useful`, con $P_{useful} = \sum_i m_i c_p \dot T_i$ para las capas entre $T_{min}$ y $T_{max}$.
   - Rozamiento interno lineal (`NominalLaminarFlow`). En un depósito de 4,6 m de diámetro es despreciable y hace robusta la inversión de flujo entre carga y descarga.
3. **`CicloCombinadoDeposito`**:
   - `tank` pasa a ser `replaceable`.
   - Nueva variable `Q_delivered`, que vale 0 en el ensayo de carga.
   - El balance pasa a ser `Q_storage = Q_into_tank − Q_loss − Q_delivered`.
4. **Nuevos `DischargeHX` y `StratifiedTankHP`**: la salida HeatPort (apartado 2).
5. **Nuevos ensayos**: `TestDepositoHeatPort_Q`, `TestDepositoHeatPort_T` y `CentralHeatPort`.

---

## 2. Salida del depósito tipo HeatPort: física implementada

`StratifiedTankHP` es el mismo depósito estratificado con una salida `heatPort_dis` (variables **T** y **Q_flow**). Por dentro lleva una bomba ideal y un intercambiador: toma agua de la capa superior y la devuelve enfriada a la inferior.

Modelo del intercambiador: corriente de agua contra un nodo térmico de temperatura uniforme ($C_r = 0$):

$$C = \dot m\,c_p,\qquad \varepsilon = 1 - e^{-UA/C},\qquad Q = \varepsilon\,C\,(T_{in} - T_{port}),\qquad T_{out} = T_{in} - \frac{Q}{C}$$

- **Caudal** (modo por defecto): el necesario para que el agua vuelva al depósito a $T_{ret,set} = 50$ °C:
  $$\dot m = \frac{Q}{c_p\,(T_{in} - T_{ret,set})}$$
  limitado entre 0,05 y 15 kg/s. Con `use_m_flow_in = true` el caudal se impone por señal.
- **Funciona con las dos causalidades del HeatPort**:
  - Si el consumidor impone **Q** (p. ej. `PrescribedHeatFlow`), el modelo devuelve $T_{port}$ y $T_{out}$.
  - Si el consumidor impone **T** (p. ej. `FixedTemperature` o una capacidad térmica), el modelo devuelve $Q$ y $T_{out}$.
- **Salidas** para el grupo de Demanda: `Q_dis`, `T_dis_supply` (impulsión, $T_{in}$), `T_dis_return` ($T_{out}$), `m_dis` y `T_port`.
- **Flags**: `dis.saturated` (bomba al máximo) y `dis.depleted` (impulsión < 50 °C).

**Qué temperatura da el HeatPort.** Con $UA = 150$ kW/K la eficacia es alta ($\varepsilon$ de 0,94 a 1), así que $T_{port}$ queda **cerca de la temperatura de retorno**, no de la de impulsión. Es la física de un puerto térmico con una sola T: el calor solo pasa si el consumidor está más frío que el agua. Si el grupo de Demanda necesita la temperatura de impulsión, la tiene en `T_dis_supply`.

---

## 3. Resultados

### 3.1 Depósito solo, el consumidor impone Q (`TestDepositoHeatPort_Q`)
Depósito lleno a 90 °C, sin carga, demanda sinusoidal de 0,4 MW de media (9,6 MWh/día, unas 9,3 MWh de capacidad útil).

| h | Q pedido (kW) | Q entregado (kW) | T impulsión (°C) | T retorno (°C) | T_port (°C) | ṁ (kg/s) | SOC |
|---|---|---|---|---|---|---|---|
| 0 | 160 | 160 | 90,0 | 50,0 | 50,0 | 0,96 | 1,00 |
| 8 | 880 | 880 | 88,2 | 50,0 | 49,9 | 5,5 | 0,48 |
| 12 | 640 | 640 | 69,3 | 50,0 | 49,8 | 7,9 | 0,13 |
| 14 | 400 | 400 | 54,5 | 48,2 | 47,5 | **15 (saturada)** | 0,02 |
| 24 | 160 | 160 | 48,0 | 45,4 | 45,2 | 15 (saturada) | 0 |

- Lo entregado coincide siempre con lo pedido y el retorno se mantiene en 50 °C mientras hay carga.
- A medida que el depósito se vacía, la impulsión baja y el caudal sube hasta saturarse. A partir de ahí el retorno y $T_{port}$ caen.
- Balance de energía: el residuo es $\dot m\,g\,H$ (118 J/kg, el trabajo de subir el agua 12 m). Es menos del 1 %, despreciable.

### 3.2 Depósito solo, el consumidor impone T (`TestDepositoHeatPort_T`)
Consumidor a 45 °C, caudal según una tabla inventada (2, 8, 0 y 5 kg/s).

| h | ṁ (kg/s) | Q resultante (kW) | T impulsión (°C) | T retorno (°C) | SOC |
|---|---|---|---|---|---|
| 0 | 2 | 377 | 90,0 | 45,0 | 1,00 |
| 7 | 8 | 1479 | 89,7 | 45,5 | 0,60 |
| 9 | 8 | 1302 | 84,3 | 45,5 | 0,32 |
| 20 | 5 | 513 | 69,6 | 45,0 | 0,11 |
| 22 | 5 | 310 | 59,8 | 45,0 | 0,04 |

- La potencia resulta de $Q = \varepsilon\,\dot m\,c_p\,(T_{in} - T_{port})$ y baja sola cuando el depósito se enfría.
- Con esta causalidad **nunca se enfría el agua por debajo de la temperatura del consumidor**, así que es físicamente más segura.

### 3.3 Planta completa con demanda por el HeatPort (`CentralHeatPort`, 72 h)
Combustible constante: la central siempre a plena carga, 2,02 MWe y 2,05 MW de calor. Demanda inventada sinusoidal: media 1,0 MW, punta 2,2 MW (8 h), cero unas 5 h por la noche. Depósito inicial a 70 °C (SOC 0,5).

**Evolución**
- **0–16 h**: el depósito se carga y llega a SOC = 1 a las 16–17 h. La torre ya rechaza entre 70 y 460 kW durante la carga (`coolingBeforeFull` activo unas 9 h): 1,3 MWh desperdiciados antes de llenarse.
- **Punta (6–10 h, 30–34 h, 54–58 h)**: la demanda (2,2 MW) supera a la central (2,05 MW).
  - El flujo dentro del depósito se invierte (−0,8 kg/s) y el depósito cubre el déficit.
  - El fondo baja de 95 a unos 80 °C y el SOC solo cae a 0,977.
  - La torre se para.
  - La bomba de descarga llega a unos 13 kg/s, sin saturarse.
- **Noche (sin demanda)**: la torre rechaza toda la producción, unos 2,04 MW.
- **Temperaturas**:
  - Impulsión al intercambiador: 90–95 °C.
  - Retorno: 50 °C.
  - $T_{port}$: 47,2–50 °C (2,8 K por debajo del retorno en la punta, con $\varepsilon = 0,94$).
  - El depósito se queda a **95 °C**, por encima de su referencia de 90 °C.
  - El HeatPort no llega a saturarse en ningún momento.

**Balance de un día en régimen (día 2, 24–48 h)**

| Concepto | MWh/día |
|---|---|
| Combustible (PCI) | 122,1 |
| Electricidad neta | 48,5 |
| Calor producido | 49,1 |
| Calor entregado al consumidor | 24,6 |
| Calor rechazado en la torre | 24,4 (**50 % del calor producido**) |
| Variación del depósito | ≈ 0 |

- Aprovechamiento del día: $(48{,}5 + 24{,}6)/122{,}1 = $ **0,60**. Acumulado en 72 h: 0,61.
- `eta_useful` instantáneo: 0,40 por la noche (solo electricidad) y 0,80 en la punta (todo aprovechado).

**Economía orientativa (día 2).** Calculada a mano con los precios del bloque `Economics`: 80 €/MWh de electricidad, 60 €/MWh de calor, 35 €/MWh de gas, 70 €/t de CO₂ y 0,202 t/MWh.
- Coste de producir 1 MWh: unos 61 €.
- Calor rechazado: unos **1.500 €/día**.
- Margen de operación (sin CAPEX ni O&M): 3.883 + 1.475 − 4.274 − 1.727 = **−643 €/día**.

### 3.4 Revisión de los ensayos de la semana pasada (24 h, sin demanda)

| Ensayo | P_el (kWe) | Q central (kW) | Torre en t = 0 (kW) | SOC a las 4 h | Rechazado en 24 h (MWh) | Aprovechamiento acumulado |
|---|---|---|---|---|---|---|
| Depósito a 70 °C | 2022 | 2046 | 766 | 0,95 | 43,3 | 0,435 |
| Depósito frío (50 °C) | 2022 | 2046 | 0 | 0,82 | 38,6 | 0,473 |
| Depósito lleno (90 °C) | 2022 | 2046 | 1787 | 1,00 | 47,9 | 0,398 |
| Potencia 125 % | 2528 | 2558 | 0 | 0,93 | 50,9 | 0,458 |

- **Modificar la potencia**: la palanca es `m_fuel` junto con `m_air` (con `m_charge` y `Q_tower_max` escalados en proporción). Así la TIT y los rendimientos no cambian (η_el = 0,398, η bruto = 0,80) y la potencia escala de forma lineal.
- **La torre trabaja con el depósito lleno**: confirmado, al llenarse rechaza el 100 % del calor. Pero también rechaza antes de llenarse (ver conclusiones).
- **Indicador de rendimiento con el depósito lleno**: `eta_useful` baja de 0,80 a 0,40 (= η_el) al llenarse. Funciona.
- **`CentralCompleta`** ya simula 72 h. Con una demanda de 1,5 MW de media, el edificio no cubre la punta (3,1 de 3,3 MW a las 8 h). Rechaza 12 MWh/día (unos 750 €/día) y su margen es de unos +96 €/día.

---

## 4. Conclusiones

1. **La salida HeatPort funciona** y está lista para conectar con el grupo de Demanda: `tank.heatPort_dis`.
   - Calcula, a partir de la temperatura de impulsión y del caudal, la temperatura de retorno y el calor entregado.
   - El balance de energía se cumple.
   - Admite las dos causalidades del HeatPort.
2. **Hay que acordar con el grupo de Demanda la causalidad del HeatPort.**
   - Si imponen **Q** con una fuente ideal, el modelo entrega lo que pidan aunque no haya energía. Con una demanda mayor que central + depósito, el agua se enfría sin límite: con 1,5 MW de media llegó a menos de 5 °C y la simulación se paró.
   - Su modelo debe reducir Q cuando $T_{port}$ baja, o bien imponer su temperatura (causalidad T, físicamente más segura).
3. **Límites físicos de la descarga con los valores actuales**:
   - Potencia máxima a 50 °C de retorno: $\dot m_{max} c_p \Delta T = 15 \cdot 4184 \cdot 40 \approx 2{,}5$ MW.
   - Energía útil del depósito: 9,3 MWh (unas 6 h a 1,5 MW).
4. **El depósito casi no se usa con la central a carga constante.** En régimen, el SOC oscila solo entre 0,98 y 1 y la torre tira el 50 % del calor producido (unos 1.500 €/día). El depósito solo cubre los ~150 kW de déficit en la punta.
   - Falta el **control de la central** que pide el profesor: modular o parar por SOC con histéresis («si no hay demanda y el depósito está lleno, no se produce»).
   - Ese control es el que hará trabajar al depósito y bajará el rechazo y el coste.
5. **Control de la torre.** Ahora actúa por temperatura de retorno (consigna 55 °C), no por el estado del depósito.
   - Rechaza calor antes de que el depósito esté lleno: 766 kW desde t = 0 con el depósito a 70 °C, y 1,3 MWh el primer día del ensayo completo.
   - El depósito se estabiliza a 95 °C, por encima de su referencia de 90 °C.
   - **Opciones a decidir**: activar la torre por SOC o por la temperatura del fondo del depósito, o subir su consigna.
6. **Economía**: con la central siempre a plena carga y estos precios orientativos, el margen de operación es negativo (−643 €/día con 1 MW de demanda media). Las cifras sirven para comparar estrategias de control, no para concluir la viabilidad.

## 5. Siguientes pasos propuestos
1. Acordar con el grupo de Demanda la causalidad del HeatPort, las temperaturas (impulsión y retorno) y su perfil de demanda.
2. Implementar el control de la central por SOC (modos carga, espera y descarga) y repetir `CentralHeatPort`.
3. Decidir el control de la torre (por SOC frente a por T de retorno) y la consigna de temperatura máxima del depósito.
4. Añadir el bloque `Economics` a `CentralHeatPort` para tener el coste del rechazo y el margen dentro del modelo.
5. Revisar el dimensionado (V del depósito, UA de descarga, caudal máximo) cuando haya demanda real.

---

## Cómo reproducir
En OMEdit: abrir `CicleGas2.mo` y simular `CicleGas2.CentralHeatPort` (72 h, unos 4 min), `TestDepositoHeatPort_Q` o `TestDepositoHeatPort_T`.
Variables a graficar:
- `Q_dem`, `Q_dis`, `Q_plant`, `Q_rejected`
- `tank.T_dis_supply`, `T_dis_return`, `T_port`, `T_top`, `T_bottom`
- `m_dis`, `SOC_useful`, `eta_useful`, `eta_useful_accum`, `tankFull`, `towerActive`, `performance.coolingBeforeFull`
