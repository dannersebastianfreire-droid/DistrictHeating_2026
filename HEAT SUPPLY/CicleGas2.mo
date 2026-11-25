package CicleGas2 "v2: cicle combinat (gas + vapor) + dipòsit + vàlvula 3 vies + torre + demanda + economia. Dimensionat per ~2 MW de calor (≈200 habitatges)"
  extends Modelica.Icons.Package;
  // ======================================================================
  //  CANVIS RESPECTE A CicleGas (v1)
  //   - Generator restaurat (a la v1 s'havien arrossegat components a dins
  //     i s'havien perdut les entrades W_turb, W_comp1, W_comp2 i P_el).
  //   - Nous: cicle de vapor (SteamGenerator, SteamTurbine, CondenserDH,
  //     FeedPump, GeneratorCC), dipòsit (StratifiedTank), vàlvula de 3 vies
  //     (ThreeWayValve), bomba ideal (IdealPump), torre (CoolingTower),
  //     demanda (DemandaSinus + BuildingDemand), Economics i WeatherProfile.
  //   - Intercanviadors: ThermalCollector -> un PrescribedHeatFlow per node
  //     (el col·lector forçava els 2 nodes a la mateixa T i sobredeterminava el sistema).
  //   - Escala: 5 kg/s d'aire (x10 respecte a la v1) -> ~2 MW de calor.
  // ======================================================================

  // ======================================================================
  //  CONNECTORS
  // ======================================================================

  connector GasIn "Entrada de gas (cabal, T, p)"
    input Modelica.Units.SI.MassFlowRate m_flow;
    input Modelica.Units.SI.Temperature T;
    input Modelica.Units.SI.AbsolutePressure p;
    annotation(
      Icon(graphics = {Ellipse(extent = {{-100, 100}, {100, -100}}, lineColor = {0, 128, 255}, fillColor = {0, 128, 255}, fillPattern = FillPattern.Solid)}));
  end GasIn;

  connector GasOut "Sortida de gas (cabal, T, p)"
    output Modelica.Units.SI.MassFlowRate m_flow;
    output Modelica.Units.SI.Temperature T;
    output Modelica.Units.SI.AbsolutePressure p;
    annotation(
      Icon(graphics = {Ellipse(extent = {{-100, 100}, {100, -100}}, lineColor = {0, 128, 255}, fillColor = {255, 255, 255}, fillPattern = FillPattern.Solid)}));
  end GasOut;

  connector SteamIn "Entrada del cicle de vapor (cabal, entalpia, pressió)"
    input Modelica.Units.SI.MassFlowRate m_flow;
    input Modelica.Units.SI.SpecificEnthalpy h(start = 1e6, nominal = 1e6);
    input Modelica.Units.SI.AbsolutePressure p(start = 1e6, nominal = 1e6);
    annotation(
      Icon(graphics = {Rectangle(extent = {{-100, 100}, {100, -100}}, lineColor = {128, 0, 128}, fillColor = {128, 0, 128}, fillPattern = FillPattern.Solid)}));
  end SteamIn;

  connector SteamOut "Sortida del cicle de vapor (cabal, entalpia, pressió)"
    output Modelica.Units.SI.MassFlowRate m_flow;
    output Modelica.Units.SI.SpecificEnthalpy h(start = 1e6, nominal = 1e6);
    output Modelica.Units.SI.AbsolutePressure p(start = 1e6, nominal = 1e6);
    annotation(
      Icon(graphics = {Rectangle(extent = {{-100, 100}, {100, -100}}, lineColor = {128, 0, 128}, fillColor = {255, 255, 255}, fillPattern = FillPattern.Solid)}));
  end SteamOut;

  // ======================================================================
  //  CICLE DE GAS (igual que la v1, valors per defecte a escala 2 MW)
  // ======================================================================

  model AirInlet "Aire ambient (estat 1)"
    parameter Modelica.Units.SI.Temperature T1 = 288.15 "Temperatura de l'aire";
    parameter Modelica.Units.SI.AbsolutePressure p1 = 1.013e5 "Pressió de l'aire";
    parameter Modelica.Units.SI.MassFlowRate m_air = 5 "Cabal d'aire (fixa la mida de la màquina)";
    GasOut outlet annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
  equation
    outlet.m_flow = m_air;
    outlet.T = T1;
    outlet.p = p1;
    annotation(
      Icon(graphics = {Rectangle(extent = {{-100, 40}, {100, -40}}, lineColor = {0, 0, 0}, fillColor = {210, 235, 255}, fillPattern = FillPattern.Solid), Text(extent = {{-100, 30}, {100, -30}}, textString = "Aire"), Text(extent = {{-150, -50}, {150, -80}}, textString = "%name", textColor = {0, 0, 255})}));
  end AirInlet;

  model Compressor "Compressor: relació de compressió + rendiment isentròpic"
    parameter Real PR = 4 "Relació de compressió p_out/p_in";
    parameter Real eta_is = 0.86 "Rendiment isentròpic";
    parameter Modelica.Units.SI.SpecificHeatCapacity cp = 1005 "cp de l'aire";
    parameter Real gamma = 1.4 "cp/cv de l'aire";
    GasIn inlet annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    GasOut outlet annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    Modelica.Blocks.Interfaces.RealOutput W(unit = "W") "Potència consumida" annotation(
      Placement(transformation(extent = {{-10, -10}, {10, 10}}, rotation = -90, origin = {0, -110})));
    Modelica.Units.SI.Temperature T_s "Temperatura de sortida isentròpica";
  equation
    T_s = inlet.T*PR^((gamma - 1)/gamma);
    outlet.T = inlet.T + (T_s - inlet.T)/eta_is;
    outlet.p = inlet.p*PR;
    outlet.m_flow = inlet.m_flow;
    W = inlet.m_flow*cp*(outlet.T - inlet.T);
    annotation(
      Icon(graphics = {Polygon(points = {{-80, 60}, {80, 30}, {80, -30}, {-80, -60}, {-80, 60}}, lineColor = {0, 0, 0}, fillColor = {120, 150, 220}, fillPattern = FillPattern.Solid), Text(extent = {{-60, 20}, {60, -20}}, textString = "C"), Text(extent = {{-150, 100}, {150, 70}}, textString = "%name", textColor = {0, 0, 255})}));
  end Compressor;

  model Intercooler "Interrefrigerador: refreda l'aire entre compressors (eficàcia)"
    parameter Real eps = 0.8 "Eficàcia de l'intercanviador";
    parameter Modelica.Units.SI.Temperature T_cw = 293.15 "Temperatura de l'aigua de refrigeració";
    parameter Real dp_rel = 0.02 "Pèrdua de pressió relativa";
    parameter Modelica.Units.SI.SpecificHeatCapacity cp = 1005 "cp de l'aire";
    GasIn inlet annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    GasOut outlet annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    Modelica.Blocks.Interfaces.RealOutput Q(unit = "W") "Calor treta a l'aire (a l'aigua de refrigeració)" annotation(
      Placement(transformation(extent = {{-10, -10}, {10, 10}}, rotation = -90, origin = {0, -110})));
  equation
    outlet.T = inlet.T - eps*(inlet.T - T_cw);
    outlet.p = inlet.p*(1 - dp_rel);
    outlet.m_flow = inlet.m_flow;
    Q = inlet.m_flow*cp*(inlet.T - outlet.T);
    annotation(
      Icon(graphics = {Rectangle(extent = {{-70, 50}, {70, -50}}, lineColor = {0, 0, 0}, fillColor = {220, 220, 220}, fillPattern = FillPattern.Solid), Line(points = {{-60, 0}, {-40, 30}, {-20, -30}, {0, 30}, {20, -30}, {40, 30}, {60, 0}}, color = {0, 0, 0}, thickness = 0.5), Text(extent = {{-150, 90}, {150, 60}}, textString = "%name", textColor = {0, 0, 255})}));
  end Intercooler;

  model CombustionChamber "Cambra de combustió: calor del gas natural"
    parameter Modelica.Units.SI.SpecificEnergy PCI = 48e6 "Poder calorífic inferior del gas natural";
    parameter Real eta_cc = 0.99 "Rendiment de combustió";
    parameter Real dp_rel = 0.04 "Pèrdua de pressió relativa";
    parameter Modelica.Units.SI.SpecificHeatCapacity cp_g = 1150 "cp dels gasos";
    GasIn inlet annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    GasOut outlet annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    Modelica.Blocks.Interfaces.RealInput m_fuel(unit = "kg/s") "Cabal de gas natural" annotation(
      Placement(transformation(extent = {{-20, -20}, {20, 20}}, rotation = -90, origin = {0, 120})));
    Modelica.Blocks.Interfaces.RealOutput Q_fuel(unit = "W") "Potència del combustible (PCI)" annotation(
      Placement(transformation(extent = {{-10, -10}, {10, 10}}, rotation = -90, origin = {0, -110})));
  equation
    Q_fuel = max(m_fuel, 0)*PCI;
    outlet.m_flow = inlet.m_flow + max(m_fuel, 0);
    outlet.T = inlet.T + eta_cc*Q_fuel/(max(outlet.m_flow, 1e-3)*cp_g);
    outlet.p = inlet.p*(1 - dp_rel);
    annotation(
      Icon(graphics = {Rectangle(extent = {{-80, 50}, {80, -50}}, lineColor = {0, 0, 0}, fillColor = {255, 170, 120}, fillPattern = FillPattern.Solid, radius = 25), Polygon(points = {{0, 35}, {20, 0}, {10, -30}, {-10, -30}, {-20, 0}, {0, 35}}, lineColor = {200, 60, 0}, fillColor = {255, 90, 0}, fillPattern = FillPattern.Solid), Text(extent = {{-150, -60}, {150, -90}}, textString = "%name", textColor = {0, 0, 255})}));
  end CombustionChamber;

  model Turbine "Turbina de gas: expansió fins a la pressió d'escapament + rendiment isentròpic"
    parameter Modelica.Units.SI.AbsolutePressure p_out = 1.05e5 "Pressió d'escapament (atm + pèrdua HRSG/economitzador)";
    parameter Real eta_is = 0.89 "Rendiment isentròpic";
    parameter Modelica.Units.SI.SpecificHeatCapacity cp_g = 1150 "cp dels gasos";
    parameter Real gamma_g = 1.33 "cp/cv dels gasos";
    GasIn inlet annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    GasOut outlet annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    Modelica.Blocks.Interfaces.RealOutput W(unit = "W") "Potència produïda" annotation(
      Placement(transformation(extent = {{-10, -10}, {10, 10}}, rotation = -90, origin = {0, -110})));
    Modelica.Units.SI.Temperature T_s "Temperatura de sortida isentròpica";
  equation
    T_s = inlet.T*(p_out/inlet.p)^((gamma_g - 1)/gamma_g);
    outlet.T = inlet.T - eta_is*(inlet.T - T_s);
    outlet.p = p_out;
    outlet.m_flow = inlet.m_flow;
    W = inlet.m_flow*cp_g*(inlet.T - outlet.T);
    assert(inlet.p > p_out, "La pressió d'entrada a la turbina ha de ser més gran que la d'escapament");
    annotation(
      Icon(graphics = {Polygon(fillColor = {240, 140, 130}, fillPattern = FillPattern.Solid, points = {{-80, 30}, {80, 60}, {80, -60}, {-80, -30}, {-80, 30}}), Text(extent = {{-60, 20}, {60, -20}}, textString = "T"), Text(textColor = {0, 0, 255}, extent = {{-150, 100}, {150, 70}}, textString = "%name")}));
  end Turbine;

  model Generator "Eix comú + alternador (només cicle de gas): P_el = η_gen·(η_mec·W_T − W_C1 − W_C2)"
    parameter Real eta_mech = 0.99 "Rendiment mecànic de l'eix";
    parameter Real eta_gen = 0.98 "Rendiment de l'alternador";
    Modelica.Blocks.Interfaces.RealInput W_turb(unit = "W") "Potència de la turbina" annotation(
      Placement(transformation(extent = {{-140, 40}, {-100, 80}})));
    Modelica.Blocks.Interfaces.RealInput W_comp1(unit = "W") "Potència del compressor 1" annotation(
      Placement(transformation(extent = {{-140, -20}, {-100, 20}})));
    Modelica.Blocks.Interfaces.RealInput W_comp2(unit = "W") "Potència del compressor 2" annotation(
      Placement(transformation(extent = {{-140, -80}, {-100, -40}})));
    Modelica.Blocks.Interfaces.RealOutput P_el(unit = "W") "Electricitat neta a la xarxa" annotation(
      Placement(transformation(extent = {{100, -10}, {120, 10}})));
  equation
    P_el = eta_gen*(eta_mech*W_turb - W_comp1 - W_comp2);
    annotation(
      Icon(graphics = {Ellipse(extent = {{-60, 60}, {60, -60}}, lineColor = {0, 0, 0}, fillColor = {230, 230, 230}, fillPattern = FillPattern.Solid), Text(extent = {{-40, 30}, {40, -30}}, textString = "G"), Text(extent = {{-150, 100}, {150, 70}}, textString = "%name", textColor = {0, 0, 255})}));
  end Generator;

  model HeatRecovery "Economitzador (Intercanviador 2): gasos d'escapament -> aigua de la xarxa (eficàcia)"
    replaceable package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater constrainedby Modelica.Media.Interfaces.PartialMedium "Aigua" annotation(
       choicesAllMatching = true);
    parameter Real eps = 0.85 "Eficàcia del recuperador";
    parameter Modelica.Units.SI.SpecificHeatCapacity cp_g = 1150 "cp dels gasos";
    parameter Modelica.Units.SI.Temperature T_stack_min = 363.15 "T mínima a la xemeneia (90 °C)";
    parameter Modelica.Units.SI.Length length = 5 "Longitud del tub d'aigua";
    parameter Modelica.Units.SI.Diameter diameter = 0.1 "Diàmetre del tub d'aigua (0,1 m per a ~12 kg/s)";
    GasIn gasIn "Gasos d'escapament (estat 6)" annotation(
      Placement(transformation(extent = {{-10, 90}, {10, 110}})));
    GasOut gasOut "Cap a la xemeneia (estat 7)" annotation(
      Placement(transformation(extent = {{-10, -110}, {10, -90}})));
    Modelica.Fluid.Interfaces.FluidPort_a port_a(redeclare package Medium = Medium) "Entrada d'aigua freda" annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    Modelica.Fluid.Interfaces.FluidPort_b port_b(redeclare package Medium = Medium) "Sortida d'aigua calenta" annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    Modelica.Blocks.Interfaces.RealOutput Q(unit = "W") "Calor recuperada" annotation(
      Placement(transformation(extent = {{100, -70}, {120, -50}})));
    Modelica.Fluid.Pipes.DynamicPipe waterSide(redeclare package Medium = Medium, length = length, diameter = diameter, nNodes = 2, modelStructure = Modelica.Fluid.Types.ModelStructure.a_v_b, use_HeatTransfer = true, momentumDynamics = Modelica.Fluid.Types.Dynamics.SteadyState) annotation(
      Placement(transformation(extent = {{-10, -10}, {10, 10}})));
    Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow heat[2](each alpha = 0) "Calor repartida entre els 2 nodes del tub (v2: substitueix el ThermalCollector)" annotation(
      Placement(transformation(extent = {{-40, 50}, {-20, 70}})));
    Modelica.Units.SI.Temperature T_w_in "Temperatura de l'aigua d'entrada";
    Modelica.Units.SI.ThermalConductance C_g "Capacitat calorífica dels gasos";
    Modelica.Units.SI.ThermalConductance C_w "Capacitat calorífica de l'aigua";
  equation
    T_w_in = Medium.temperature(Medium.setState_phX(port_a.p, inStream(port_a.h_outflow)));
    C_g = gasIn.m_flow*cp_g;
    C_w = max(port_a.m_flow, 0)*Medium.specificHeatCapacityCp(Medium.setState_phX(port_a.p, inStream(port_a.h_outflow)));
// eficàcia, sense refredar els gasos per sota de T_stack_min
    Q = min(eps*min(C_g, C_w)*max(gasIn.T - T_w_in, 0), C_g*max(gasIn.T - T_stack_min, 0));
    gasOut.m_flow = gasIn.m_flow;
    gasOut.p = gasIn.p;
    gasOut.T = gasIn.T - Q/max(C_g, 1e-3);
    heat.Q_flow = fill(Q/2, 2);
    connect(heat.port, waterSide.heatPorts);
    connect(port_a, waterSide.port_a);
    connect(waterSide.port_b, port_b);
    annotation(
      Icon(graphics = {Rectangle(extent = {{-80, 60}, {80, -60}}, lineColor = {0, 0, 0}, fillColor = {255, 200, 150}, fillPattern = FillPattern.Solid, radius = 10), Line(points = {{-70, 20}, {-50, 40}, {-30, 0}, {-10, 40}, {10, 0}, {30, 40}, {50, 0}, {70, 20}}, color = {200, 30, 30}, thickness = 0.5), Line(points = {{-70, -20}, {-50, 0}, {-30, -40}, {-10, 0}, {10, -40}, {30, 0}, {50, -40}, {70, -20}}, color = {0, 90, 200}, thickness = 0.5), Text(extent = {{-150, -70}, {150, -100}}, textString = "%name", textColor = {0, 0, 255})}));
  end HeatRecovery;

  model Chimney "Xemeneia: mostra l'estat 7"
    GasIn inlet annotation(
      Placement(transformation(extent = {{-10, 90}, {10, 110}})));
    Modelica.Units.SI.Temperature T7 = inlet.T "Temperatura a la xemeneia";
    Modelica.Units.SI.AbsolutePressure p7 = inlet.p "Pressió a la xemeneia";
    annotation(
      Icon(graphics = {Polygon(points = {{-30, 90}, {30, 90}, {50, -90}, {-50, -90}, {-30, 90}}, lineColor = {0, 0, 0}, fillColor = {180, 180, 180}, fillPattern = FillPattern.Solid), Text(extent = {{-150, -95}, {150, -125}}, textString = "%name", textColor = {0, 0, 255})}));
  end Chimney;

  // ======================================================================
  //  CICLE DE VAPOR (Rankine de contrapressió). Propietats: IF97
  // ======================================================================

  model SteamGenerator "Caldera de recuperació (HRSG) d'un nivell: economitzador + evaporador + sobreescalfador"
    package Steam = Modelica.Media.Water.StandardWater;
    parameter Modelica.Units.SI.AbsolutePressure p_steam = 20e5 "Pressió del vapor viu";
    parameter Modelica.Units.SI.Temperature T_steam = 723.15 "Temperatura del vapor viu (450 °C)";
    parameter Modelica.Units.SI.TemperatureDifference dT_pinch = 10 "Pinch point (gasos - saturació)";
    parameter Modelica.Units.SI.SpecificHeatCapacity cp_g = 1150 "cp dels gasos";
    GasIn gasIn "Gasos de la turbina de gas" annotation(
      Placement(transformation(extent = {{-10, 90}, {10, 110}})));
    GasOut gasOut "Gasos cap a l'economitzador de xarxa" annotation(
      Placement(transformation(extent = {{-10, -110}, {10, -90}})));
    SteamOut steamOut "Vapor viu cap a la turbina" annotation(
      Placement(transformation(extent = {{90, 30}, {110, 50}})));
    SteamIn feedIn "Aigua d'alimentació (de la bomba)" annotation(
      Placement(transformation(extent = {{90, -50}, {110, -30}})));
    Modelica.Blocks.Interfaces.RealOutput Q(unit = "W") "Calor total passada al vapor (P_q1)" annotation(
      Placement(transformation(extent = {{-100, -10}, {-120, 10}})));
    Modelica.Units.SI.Temperature T_sat "Temperatura de saturació";
    Modelica.Units.SI.SpecificEnthalpy h_l "Entalpia de líquid saturat";
    Modelica.Units.SI.SpecificEnthalpy h_v "Entalpia del vapor viu";
    Modelica.Units.SI.Temperature T_g_pinch "Temperatura dels gasos al pinch";
    Modelica.Units.SI.HeatFlowRate Q_shev "Calor al sobreescalfador + evaporador";
    Modelica.Units.SI.HeatFlowRate Q_eco "Calor a l'economitzador de la caldera";
    Modelica.Units.SI.MassFlowRate m_steam "Cabal de vapor produït";
    Modelica.Units.SI.ThermalConductance C_g "Capacitat calorífica dels gasos";
  equation
    T_sat = Steam.saturationTemperature(p_steam);
    h_l = Steam.bubbleEnthalpy(Steam.setSat_p(p_steam));
    h_v = Steam.specificEnthalpy_pT(p_steam, T_steam);
    C_g = gasIn.m_flow*cp_g;
// el cabal de vapor el fixa el pinch: els gasos no poden baixar de T_sat + pinch a l'evaporador
    T_g_pinch = T_sat + dT_pinch;
    Q_shev = C_g*max(gasIn.T - T_g_pinch, 0);
    m_steam = Q_shev/(h_v - h_l);
    Q_eco = m_steam*max(h_l - feedIn.h, 0);
    Q = Q_shev + Q_eco;
    gasOut.m_flow = gasIn.m_flow;
    gasOut.p = gasIn.p;
    gasOut.T = gasIn.T - Q/max(C_g, 1e-3);
    steamOut.m_flow = m_steam;
    steamOut.h = h_v;
    steamOut.p = p_steam;
    assert(gasIn.T > T_steam + 20, "HRSG: els gasos d'entrada no són prou calents per al vapor viu demanat", AssertionLevel.warning);
    annotation(
      Icon(graphics = {Rectangle(extent = {{-60, 90}, {60, -90}}, lineColor = {0, 0, 0}, fillColor = {255, 220, 180}, fillPattern = FillPattern.Solid), Line(points = {{-40, 60}, {40, 60}, {-40, 30}, {40, 30}, {-40, 0}, {40, 0}, {-40, -30}, {40, -30}, {-40, -60}, {40, -60}}, color = {128, 0, 128}, thickness = 0.5), Text(extent = {{-150, -95}, {150, -125}}, textString = "%name", textColor = {0, 0, 255})}));
  end SteamGenerator;

  model SteamTurbine "Turbina de vapor de contrapressió: expansió fins a la pressió de condensació"
    package Steam = Modelica.Media.Water.StandardWater;
    parameter Real eta_is = 0.80 "Rendiment isentròpic";
    parameter Modelica.Units.SI.Temperature T_cond = 373.15 "Temperatura de condensació = T impulsió + LTD (100 °C)";
    SteamIn inlet annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    SteamOut outlet annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    Modelica.Blocks.Interfaces.RealOutput W(unit = "W") "Potència produïda" annotation(
      Placement(transformation(extent = {{-10, -10}, {10, 10}}, rotation = -90, origin = {0, -110})));
    Modelica.Units.SI.AbsolutePressure p_cond "Contrapressió";
    Modelica.Units.SI.SpecificEntropy s_in "Entropia a l'entrada";
    Modelica.Units.SI.SpecificEnthalpy h_out_s(start = 2.6e6) "Entalpia de sortida isentròpica";
  equation
    p_cond = Steam.saturationPressure(T_cond);
    s_in = Steam.specificEntropy(Steam.setState_ph(inlet.p, inlet.h));
    h_out_s = Steam.specificEnthalpy_ps(p_cond, s_in);
    outlet.h = inlet.h - eta_is*(inlet.h - h_out_s);
    outlet.p = p_cond;
    outlet.m_flow = inlet.m_flow;
    W = inlet.m_flow*(inlet.h - outlet.h);
    annotation(
      Icon(graphics = {Polygon(fillColor = {200, 160, 220}, fillPattern = FillPattern.Solid, points = {{-80, 30}, {80, 60}, {80, -60}, {-80, -30}, {-80, 30}}), Text(extent = {{-60, 20}, {60, -20}}, textString = "TV"), Text(textColor = {0, 0, 255}, extent = {{-150, 100}, {150, 70}}, textString = "%name")}));
  end SteamTurbine;

  model CondenserDH "Condensador: el vapor condensa i escalfa l'aigua de la xarxa (P_q3)"
    package Steam = Modelica.Media.Water.StandardWater;
    replaceable package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater constrainedby Modelica.Media.Interfaces.PartialMedium "Aigua de la xarxa" annotation(
       choicesAllMatching = true);
    parameter Modelica.Units.SI.TemperatureDifference dT_sub = 2 "Subrefredament del condensat";
    parameter Modelica.Units.SI.Length length = 5 "Longitud del tub d'aigua";
    parameter Modelica.Units.SI.Diameter diameter = 0.1 "Diàmetre del tub d'aigua";
    SteamIn inlet "Vapor de la turbina" annotation(
      Placement(transformation(extent = {{-10, 90}, {10, 110}})));
    SteamOut outlet "Condensat cap a la bomba" annotation(
      Placement(transformation(extent = {{-10, -110}, {10, -90}})));
    Modelica.Fluid.Interfaces.FluidPort_a port_a(redeclare package Medium = Medium) "Entrada d'aigua de la xarxa" annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    Modelica.Fluid.Interfaces.FluidPort_b port_b(redeclare package Medium = Medium) "Sortida d'aigua calenta" annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    Modelica.Blocks.Interfaces.RealOutput Q(unit = "W") "Calor cedida a la xarxa" annotation(
      Placement(transformation(extent = {{100, -70}, {120, -50}})));
    Modelica.Fluid.Pipes.DynamicPipe waterSide(redeclare package Medium = Medium, length = length, diameter = diameter, nNodes = 2, modelStructure = Modelica.Fluid.Types.ModelStructure.a_v_b, use_HeatTransfer = true, momentumDynamics = Modelica.Fluid.Types.Dynamics.SteadyState) annotation(
      Placement(transformation(extent = {{-10, -10}, {10, 10}})));
    Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow heat[2](each alpha = 0) "Calor repartida entre els 2 nodes del tub (v2: substitueix el ThermalCollector)" annotation(
      Placement(transformation(extent = {{-40, 50}, {-20, 70}})));
    Modelica.Units.SI.Temperature T_cond "Temperatura de condensació";
    Modelica.Units.SI.Temperature T_w_out "Temperatura de sortida de l'aigua";
  equation
    T_cond = Steam.saturationTemperature(inlet.p);
    outlet.h = Steam.specificEnthalpy_pT(inlet.p, T_cond - dT_sub);
    outlet.p = inlet.p;
    outlet.m_flow = inlet.m_flow;
    Q = inlet.m_flow*max(inlet.h - outlet.h, 0);
    heat.Q_flow = fill(Q/2, 2);
    T_w_out = Medium.temperature(Medium.setState_phX(port_b.p, port_b.h_outflow));
    assert(T_w_out < T_cond, "Condensador: l'aigua surt més calenta que el vapor que condensa (cal més cabal o més T_cond)", AssertionLevel.warning);
    connect(heat.port, waterSide.heatPorts);
    connect(port_a, waterSide.port_a);
    connect(waterSide.port_b, port_b);
    annotation(
      Icon(graphics = {Rectangle(extent = {{-80, 80}, {80, -80}}, lineColor = {0, 0, 0}, fillColor = {230, 210, 240}, fillPattern = FillPattern.Solid, radius = 10), Line(points = {{-80, 0}, {-50, 0}, {-40, 30}, {-20, -30}, {0, 30}, {20, -30}, {40, 30}, {50, 0}, {80, 0}}, color = {0, 90, 200}, thickness = 0.5), Text(extent = {{-150, -85}, {150, -115}}, textString = "%name", textColor = {0, 0, 255})}));
  end CondenserDH;

  model FeedPump "Bomba d'alimentació: torna el condensat a la pressió de la caldera"
    package Steam = Modelica.Media.Water.StandardWater;
    parameter Modelica.Units.SI.AbsolutePressure p_out = 20e5 "Pressió de sortida (= pressió de la caldera)";
    parameter Real eta = 0.75 "Rendiment de la bomba";
    SteamIn inlet annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    SteamOut outlet annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    Modelica.Blocks.Interfaces.RealOutput W(unit = "W") "Potència consumida" annotation(
      Placement(transformation(extent = {{-10, -10}, {10, 10}}, rotation = -90, origin = {0, -110})));
    Modelica.Units.SI.Density rho "Densitat del condensat";
  equation
    rho = Steam.density(Steam.setState_ph(inlet.p, inlet.h));
    outlet.h = inlet.h + (p_out - inlet.p)/(rho*eta);
    outlet.p = p_out;
    outlet.m_flow = inlet.m_flow;
    W = inlet.m_flow*(outlet.h - inlet.h);
    annotation(
      Icon(graphics = {Ellipse(extent = {{-60, 60}, {60, -60}}, lineColor = {0, 0, 0}, fillColor = {200, 160, 220}, fillPattern = FillPattern.Solid), Polygon(points = {{-30, 40}, {50, 0}, {-30, -40}, {-30, 40}}, lineColor = {0, 0, 0}, fillColor = {255, 255, 255}, fillPattern = FillPattern.Solid), Text(extent = {{-150, 100}, {150, 70}}, textString = "%name", textColor = {0, 0, 255})}));
  end FeedPump;

  model GeneratorCC "Generador del cicle combinat: P_el = η_gen·(η_mec·(W_TG + W_TV) − W_C1 − W_C2) − W_bomba"
    parameter Real eta_mech = 0.99 "Rendiment mecànic dels eixos";
    parameter Real eta_gen = 0.98 "Rendiment dels alternadors";
    parameter Real eta_motor = 0.95 "Rendiment del motor de la bomba d'alimentació";
    Modelica.Blocks.Interfaces.RealInput W_turb(unit = "W") "Turbina de gas" annotation(
      Placement(transformation(extent = {{-140, 60}, {-100, 100}})));
    Modelica.Blocks.Interfaces.RealInput W_comp1(unit = "W") "Compressor 1" annotation(
      Placement(transformation(extent = {{-140, 20}, {-100, 60}})));
    Modelica.Blocks.Interfaces.RealInput W_comp2(unit = "W") "Compressor 2" annotation(
      Placement(transformation(extent = {{-140, -20}, {-100, 20}})));
    Modelica.Blocks.Interfaces.RealInput W_st(unit = "W") "Turbina de vapor" annotation(
      Placement(transformation(extent = {{-140, -60}, {-100, -20}})));
    Modelica.Blocks.Interfaces.RealInput W_pump(unit = "W") "Bomba d'alimentació" annotation(
      Placement(transformation(extent = {{-140, -100}, {-100, -60}})));
    Modelica.Blocks.Interfaces.RealOutput P_el(unit = "W") "Electricitat neta venuda (P_e1 + P_e2)" annotation(
      Placement(transformation(extent = {{100, -10}, {120, 10}})));
    Modelica.Units.SI.Power P_el_GT "Electricitat de la turbina de gas (P_e1)";
    Modelica.Units.SI.Power P_el_ST "Electricitat de la turbina de vapor (P_e2)";
  equation
    P_el_GT = eta_gen*(eta_mech*W_turb - W_comp1 - W_comp2);
    P_el_ST = eta_gen*eta_mech*W_st;
    P_el = P_el_GT + P_el_ST - W_pump/eta_motor;
    annotation(
      Icon(graphics = {Ellipse(extent = {{-60, 60}, {60, -60}}, lineColor = {0, 0, 0}, fillColor = {230, 230, 230}, fillPattern = FillPattern.Solid), Text(extent = {{-40, 30}, {40, -30}}, textString = "G"), Text(extent = {{-150, 100}, {150, 70}}, textString = "%name", textColor = {0, 0, 255})}));
  end GeneratorCC;

  // ======================================================================
  //  GESTIÓ DE LA CALOR (aigua de la xarxa, Modelica.Fluid)
  // ======================================================================

  model StratifiedTank "Dipòsit estratificat: tub vertical de gran diàmetre dividit en capes + pèrdues U·A"
    replaceable package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater constrainedby Modelica.Media.Interfaces.PartialMedium "Aigua" annotation(
       choicesAllMatching = true);
    parameter Modelica.Units.SI.Volume V = 200 "Volum";
    parameter Modelica.Units.SI.Height H = 12 "Alçada";
    parameter Modelica.Units.SI.Diameter D = sqrt(4*V/(Modelica.Constants.pi*H)) "Diàmetre";
    parameter Integer nSeg = 10 "Nombre de capes";
    parameter Modelica.Units.SI.CoefficientOfHeatTransfer U = 0.3 "Coeficient de pèrdues de l'aïllament";
    parameter Modelica.Units.SI.Temperature T_max = 363.15 "T del dipòsit ple (90 °C)";
    parameter Modelica.Units.SI.Temperature T_min = 323.15 "T del dipòsit buit (50 °C)";
    parameter Modelica.Units.SI.Temperature T_start = 343.15 "T inicial uniforme (70 °C)";
    parameter Modelica.Units.SI.Temperature T_amb = 288.15 "T ambient al voltant del dipòsit";
    parameter Modelica.Units.SI.AbsolutePressure p_bot_start = 3e5 "Pressió inicial a baix";
    Modelica.Fluid.Interfaces.FluidPort_a port_top(redeclare package Medium = Medium) "Connexió de dalt (calenta)" annotation(
      Placement(transformation(extent = {{-10, 90}, {10, 110}})));
    Modelica.Fluid.Interfaces.FluidPort_b port_bot(redeclare package Medium = Medium) "Connexió de baix (freda)" annotation(
      Placement(transformation(extent = {{-10, -110}, {10, -90}})));
    Modelica.Blocks.Interfaces.RealOutput SOC "Estat de càrrega (0 buit - 1 ple)" annotation(
      Placement(transformation(extent = {{100, 30}, {120, 50}})));
    Modelica.Blocks.Interfaces.RealOutput T_bot(unit = "K") "Termòmetre de la capa de baix" annotation(
      Placement(transformation(extent = {{100, -50}, {120, -30}})));
    Modelica.Fluid.Pipes.DynamicPipe tank(redeclare package Medium = Medium, length = H, diameter = D, height_ab = -H, nNodes = nSeg, modelStructure = Modelica.Fluid.Types.ModelStructure.av_vb, use_HeatTransfer = true, momentumDynamics = Modelica.Fluid.Types.Dynamics.SteadyState, T_start = T_start, p_a_start = p_bot_start - 1000*9.81*H, p_b_start = p_bot_start, redeclare model FlowModel = Modelica.Fluid.Pipes.BaseClasses.FlowModels.NominalLaminarFlow(dp_nominal = 10, m_flow_nominal = 10)) "v3: rozamiento lineal (despreciable en D ≈ 4,6 m) para que la inversión de flujo carga/descarga sea robusta" annotation(
      Placement(transformation(extent = {{-10, -10}, {10, 10}}, rotation = -90)));
    Modelica.Thermal.HeatTransfer.Components.ThermalConductor loss[nSeg](each G = U*Modelica.Constants.pi*D*H/nSeg) "Pèrdues de cada capa" annotation(
      Placement(transformation(extent = {{20, -10}, {40, 10}})));
    Modelica.Thermal.HeatTransfer.Sources.FixedTemperature ambient[nSeg](each T = T_amb) annotation(
      Placement(transformation(extent = {{80, -10}, {60, 10}})));
    Modelica.Units.SI.Temperature T_layers[nSeg] "Temperatura de cada capa (1 = dalt)";
    Modelica.Units.SI.Temperature T_top "Temperatura de la capa de dalt";
    Modelica.Units.SI.HeatFlowRate Q_loss "Pèrdues totals a l'ambient";
    Modelica.Units.SI.Energy E_stored "Energia útil emmagatzemada (sobre T_min)";
    Modelica.Units.SI.Energy E_capacity "Capacidad útil entre T_min y T_max";
    Modelica.Units.SI.Energy E_useful "Energía útil acotada por capa entre T_min y T_max";
    Modelica.Units.SI.HeatFlowRate P_useful "dE_useful/dt calculado con der(T) de cada capa (evita derivar el sistema hidráulico)";
  equation
    T_layers = tank.mediums.T;
    E_capacity = sum(tank.ms[i]*Medium.specificHeatCapacityCp(tank.mediums[i].state)*(T_max - T_min) for i in 1:nSeg);
    E_useful = sum(tank.ms[i]*Medium.specificHeatCapacityCp(tank.mediums[i].state)*min(max(T_layers[i] - T_min, 0), T_max - T_min) for i in 1:nSeg);
    P_useful = sum(tank.ms[i]*Medium.specificHeatCapacityCp(tank.mediums[i].state)*(if noEvent(T_layers[i] > T_min and T_layers[i] < T_max) then der(T_layers[i]) else 0) for i in 1:nSeg);
    T_top = T_layers[1];
    T_bot = T_layers[nSeg];
    E_stored = sum(tank.ms[i]*Medium.specificHeatCapacityCp(tank.mediums[i].state)*(T_layers[i] - T_min) for i in 1:nSeg);
    SOC = sum(T_layers[i] - T_min for i in 1:nSeg)/(nSeg*(T_max - T_min));
    Q_loss = sum(loss.Q_flow);
    connect(port_top, tank.port_a);
    connect(tank.port_b, port_bot);
    connect(tank.heatPorts, loss.port_a);
    connect(loss.port_b, ambient.port);
    annotation(
      Icon(graphics = {Rectangle(extent = {{-50, 90}, {50, -90}}, lineColor = {0, 0, 0}, fillColor = {0, 118, 207}, fillPattern = FillPattern.VerticalCylinder, radius = 20), Rectangle(extent = {{-50, 90}, {50, 20}}, lineColor = {0, 0, 0}, fillColor = {220, 60, 40}, fillPattern = FillPattern.VerticalCylinder, radius = 20), Text(extent = {{-150, -95}, {150, -125}}, textString = "%name", textColor = {0, 0, 255})}));
  end StratifiedTank;

  model DischargeHX "Descarga del depósito hacia un HeatPort: agua de arriba -> intercambiador -> vuelve por abajo"
    // Física (corriente de agua contra un nodo térmico de temperatura uniforme T_port, C_r = 0):
    //   C      = m·cp
    //   ε      = 1 - exp(-UA/C)
    //   Q      = ε·C·(T_in - T_port)          (calor que sale por el HeatPort)
    //   T_out  = T_in - Q/C                   (temperatura con la que vuelve al fondo del depósito)
    // Funciona con las dos causalidades del HeatPort:
    //   - el consumidor impone Q (PrescribedHeatFlow) -> salen T_port y T_out
    //   - el consumidor impone T (PrescribedTemperature / capacidad térmica) -> salen Q y T_out
    replaceable package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater constrainedby Modelica.Media.Interfaces.PartialMedium "Aigua" annotation(
       choicesAllMatching = true);
    parameter Modelica.Units.SI.ThermalConductance UA = 1.5e5 "UA del intercambiador de descarga";
    parameter Boolean use_m_flow_in = false "true: caudal impuesto por señal; false: caudal por ΔT de diseño";
    parameter Modelica.Units.SI.Temperature T_ret_set = 323.15 "Temperatura de retorno objetivo al depósito (50 °C), modo ΔT";
    parameter Modelica.Units.SI.MassFlowRate m_flow_max = 15 "Caudal máximo de la bomba de descarga";
    parameter Modelica.Units.SI.MassFlowRate m_flow_min = 0.05 "Caudal mínimo (evita C = 0)";
    parameter Modelica.Units.SI.TemperatureDifference dT_min = 2 "ΔT mínimo para el cálculo del caudal en modo ΔT";
    parameter Modelica.Units.SI.Temperature T_use_min = 323.15 "Por debajo de esta T de suministro el depósito se considera agotado";
    Modelica.Fluid.Interfaces.FluidPort_a port_a(redeclare package Medium = Medium) "Toma de agua caliente (arriba del depósito)" annotation(
      Placement(transformation(extent = {{-10, 90}, {10, 110}})));
    Modelica.Fluid.Interfaces.FluidPort_b port_b(redeclare package Medium = Medium) "Retorno de agua enfriada (abajo del depósito)" annotation(
      Placement(transformation(extent = {{-10, -110}, {10, -90}})));
    Modelica.Thermal.HeatTransfer.Interfaces.HeatPort_b heatPort(T(start = 323.15)) "Salida térmica hacia el consumidor (Q_flow < 0 = sale calor)" annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    Modelica.Blocks.Interfaces.RealInput m_flow_in(unit = "kg/s") if use_m_flow_in "Caudal de descarga impuesto" annotation(
      Placement(transformation(extent = {{140, -20}, {100, 20}})));
    Modelica.Blocks.Interfaces.RealOutput Q(unit = "W") "Calor entregado al consumidor" annotation(
      Placement(transformation(extent = {{100, 50}, {120, 70}})));
    Modelica.Blocks.Interfaces.RealOutput T_supply(unit = "K") "Temperatura del agua que entra al intercambiador" annotation(
      Placement(transformation(extent = {{100, 30}, {120, 50}})));
    Modelica.Blocks.Interfaces.RealOutput T_return(unit = "K") "Temperatura del agua que vuelve al depósito" annotation(
      Placement(transformation(extent = {{100, -50}, {120, -30}})));
    Modelica.Units.SI.MassFlowRate m_flow "Caudal de descarga";
    Modelica.Units.SI.SpecificHeatCapacity cp "cp del agua";
    Modelica.Units.SI.ThermalConductance C "Capacidad calorífica de la corriente";
    Real NTU "Número de unidades de transferencia";
    Real eps "Eficacia del intercambiador";
    Modelica.Units.SI.SpecificEnthalpy h_in "Entalpía de entrada";
    Boolean depleted "Suministro por debajo de T_use_min (depósito agotado)";
    Boolean saturated "La bomba de descarga está al máximo: el retorno ya no llega a T_ret_set";
    Modelica.Units.SI.TemperatureDifference dT_eff "Salto térmico de diseño usado para el caudal";
    Modelica.Units.SI.MassFlowRate m_req "Caudal pedido antes de límites";
    Modelica.Units.SI.MassFlowRate m_cap "Caudal tras el límite superior";
  protected
    Modelica.Blocks.Interfaces.RealInput m_flow_internal "Conector interno para la entrada condicional";
  equation
    connect(m_flow_in, m_flow_internal);
    if not use_m_flow_in then
      m_flow_internal = 0;
    end if;
    h_in = inStream(port_a.h_outflow);
    cp = Medium.specificHeatCapacityCp(Medium.setState_phX(port_a.p, h_in));
    T_supply = Medium.temperature(Medium.setState_phX(port_a.p, h_in));
    Q = -heatPort.Q_flow;
// caudal: impuesto, o el necesario para volver a T_ret_set con el calor que pide el consumidor
// límites suavizados (regStep): m_flow está dentro de un lazo algebraico (mezcla en el nodo superior) y un min/max con esquina hace fallar al solver
    dT_eff = Modelica.Fluid.Utilities.regStep(T_supply - T_ret_set - dT_min, T_supply - T_ret_set, dT_min, 0.5);
    m_req = if use_m_flow_in then m_flow_internal else Q/(cp*dT_eff);
    m_cap = Modelica.Fluid.Utilities.regStep(m_req - m_flow_max, m_flow_max, m_req, 0.05*m_flow_max);
    m_flow = Modelica.Fluid.Utilities.regStep(m_cap - m_flow_min, m_cap, m_flow_min, 0.5*m_flow_min);
    saturated = noEvent(m_req > m_flow_max);
    C = m_flow*cp;
    NTU = UA/C;
    eps = 1 - exp(-NTU);
    Q = eps*C*(T_supply - heatPort.T);
// hidráulica: bomba ideal (impone caudal, el salto de presión lo da el resto del circuito)
    port_a.m_flow = m_flow;
    port_a.m_flow + port_b.m_flow = 0;
    port_b.h_outflow = h_in - Q/m_flow;
    port_a.h_outflow = inStream(port_b.h_outflow);
    port_b.Xi_outflow = inStream(port_a.Xi_outflow);
    port_a.Xi_outflow = inStream(port_b.Xi_outflow);
    port_b.C_outflow = inStream(port_a.C_outflow);
    port_a.C_outflow = inStream(port_b.C_outflow);
    T_return = Medium.temperature(Medium.setState_phX(port_b.p, port_b.h_outflow));
    depleted = noEvent(T_supply < T_use_min);
    assert(T_return > 278.15, "DischargeHX: el retorno baja de 5 °C; el consumidor pide más calor del que el depósito puede dar", AssertionLevel.warning);
    annotation(
      Icon(graphics = {Rectangle(extent = {{-80, 80}, {80, -80}}, lineColor = {0, 0, 0}, fillColor = {255, 230, 200}, fillPattern = FillPattern.Solid, radius = 10), Line(points = {{0, 80}, {0, 50}, {-40, 30}, {40, 10}, {-40, -10}, {40, -30}, {0, -50}, {0, -80}}, color = {200, 30, 30}, thickness = 0.5), Line(points = {{-90, 0}, {-50, 0}}, color = {191, 0, 0}, thickness = 0.5), Text(extent = {{-150, -85}, {150, -115}}, textString = "%name", textColor = {0, 0, 255})}),
      Documentation(info = "<html><p>Interfaz de salida del depósito como <b>HeatPort</b> (T, Q_flow) para el grupo de Demanda.</p><p>Modelo: corriente de agua (m, T_in) contra un nodo térmico uniforme T_port (C_r = 0): ε = 1 - exp(-UA/(m·cp)), Q = ε·m·cp·(T_in - T_port), T_out = T_in - Q/(m·cp).</p><p>Si UA es grande, T_port tiende a T_out (temperatura de retorno). T_supply y T_return se dan como salidas para que el consumidor vea también la temperatura de impulsión.</p><p>Modo ΔT (por defecto): m = Q/(cp·(T_in - T_ret_set)), acotado entre m_flow_min y m_flow_max. Si se satura en m_flow_max, el retorno baja por debajo de T_ret_set y T_port cae: el depósito ya no puede dar la potencia pedida a esa temperatura.</p></html>"));
  end DischargeHX;

  model StratifiedTankHP "Depósito estratificado con salida tipo HeatPort (descarga por intercambiador interno)"
    extends StratifiedTank;
    parameter Modelica.Units.SI.ThermalConductance UA_dis = 1.5e5 "UA del intercambiador de descarga";
    parameter Boolean use_m_flow_in = false "true: caudal de descarga por señal";
    parameter Modelica.Units.SI.Temperature T_ret_set = T_min "Retorno objetivo al fondo del depósito";
    parameter Modelica.Units.SI.MassFlowRate m_dis_max = 15 "Caudal máximo de descarga";
    parameter Modelica.Units.SI.MassFlowRate m_dis_min = 0.05 "Caudal mínimo de descarga";
    Modelica.Thermal.HeatTransfer.Interfaces.HeatPort_b heatPort_dis "SALIDA DEL DEPÓSITO: conectar aquí el consumidor (T, Q_flow)" annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    Modelica.Blocks.Interfaces.RealInput m_dis_in(unit = "kg/s") if use_m_flow_in "Caudal de descarga impuesto" annotation(
      Placement(transformation(extent = {{-140, -80}, {-100, -40}})));
    Modelica.Blocks.Interfaces.RealOutput Q_dis(unit = "W") "Calor entregado por el HeatPort" annotation(
      Placement(transformation(extent = {{100, 70}, {120, 90}})));
    Modelica.Blocks.Interfaces.RealOutput T_dis_supply(unit = "K") "T del agua que sale de arriba hacia el intercambiador" annotation(
      Placement(transformation(extent = {{100, 50}, {120, 70}})));
    Modelica.Blocks.Interfaces.RealOutput T_dis_return(unit = "K") "T del agua que vuelve al fondo" annotation(
      Placement(transformation(extent = {{100, -70}, {120, -50}})));
    DischargeHX dis(redeclare package Medium = Medium, UA = UA_dis, use_m_flow_in = use_m_flow_in, T_ret_set = T_ret_set, m_flow_max = m_dis_max, m_flow_min = m_dis_min, T_use_min = T_min) annotation(
      Placement(transformation(extent = {{-60, -10}, {-40, 10}})));
    Modelica.Units.SI.MassFlowRate m_dis = dis.m_flow "Caudal de descarga";
    Modelica.Units.SI.Temperature T_port = heatPort_dis.T "Temperatura en el HeatPort";
  equation
    connect(tank.port_a, dis.port_a);
    connect(dis.port_b, tank.port_b);
    connect(dis.heatPort, heatPort_dis);
    connect(m_dis_in, dis.m_flow_in);
    connect(dis.Q, Q_dis);
    connect(dis.T_supply, T_dis_supply);
    connect(dis.T_return, T_dis_return);
    annotation(
      Icon(graphics = {Line(points = {{-90, 0}, {-50, 0}}, color = {191, 0, 0}, thickness = 1), Rectangle(extent = {{-100, 10}, {-80, -10}}, lineColor = {191, 0, 0}, fillColor = {191, 0, 0}, fillPattern = FillPattern.Solid)}),
      Documentation(info = "<html><p>Igual que StratifiedTank (puertos de fluido port_top/port_bot para la carga desde la central) más una <b>salida HeatPort</b> heatPort_dis para el consumidor.</p><p>Internamente: bomba ideal + intercambiador (DischargeHX) que toma agua de la capa superior y la devuelve enfriada a la capa inferior. Balance: dE/dt = H_carga - Q_dis - Q_loss.</p></html>"));
  end StratifiedTankHP;

  model IdealPump "Bomba ideal: imposa el cabal (senyal), sense pèrdues"
    replaceable package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater constrainedby Modelica.Media.Interfaces.PartialMedium "Aigua" annotation(
       choicesAllMatching = true);
    Modelica.Fluid.Interfaces.FluidPort_a port_a(redeclare package Medium = Medium) annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    Modelica.Fluid.Interfaces.FluidPort_b port_b(redeclare package Medium = Medium) annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    Modelica.Blocks.Interfaces.RealInput m_flow_set(unit = "kg/s") "Cabal imposat" annotation(
      Placement(transformation(extent = {{-20, -20}, {20, 20}}, rotation = -90, origin = {0, 120})));
    Modelica.Units.SI.PressureDifference dp = port_b.p - port_a.p "Salt de pressió que dona la bomba";
  equation
    port_a.m_flow = m_flow_set;
    port_a.m_flow + port_b.m_flow = 0;
    port_a.h_outflow = inStream(port_b.h_outflow);
    port_b.h_outflow = inStream(port_a.h_outflow);
    port_a.Xi_outflow = inStream(port_b.Xi_outflow);
    port_b.Xi_outflow = inStream(port_a.Xi_outflow);
    port_a.C_outflow = inStream(port_b.C_outflow);
    port_b.C_outflow = inStream(port_a.C_outflow);
    annotation(
      Icon(graphics = {Ellipse(extent = {{-60, 60}, {60, -60}}, lineColor = {0, 0, 0}, fillColor = {0, 118, 207}, fillPattern = FillPattern.Solid), Polygon(points = {{-30, 40}, {50, 0}, {-30, -40}, {-30, 40}}, lineColor = {0, 0, 0}, fillColor = {255, 255, 255}, fillPattern = FillPattern.Solid), Line(points = {{-100, 0}, {-60, 0}}, color = {0, 127, 255}), Line(points = {{60, 0}, {100, 0}}, color = {0, 127, 255}), Text(extent = {{-150, -65}, {150, -95}}, textString = "%name", textColor = {0, 0, 255})}));
  end IdealPump;

  model ThreeWayValve "Vàlvula de 3 vies de barreja: y = fracció d'aigua calenta (dipòsit) i 1-y de retorn (bypass)"
    replaceable package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater constrainedby Modelica.Media.Interfaces.PartialMedium "Aigua" annotation(
       choicesAllMatching = true);
    Modelica.Fluid.Interfaces.FluidPort_a port_hot(redeclare package Medium = Medium) "Entrada calenta (del dipòsit)" annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    Modelica.Fluid.Interfaces.FluidPort_a port_cold(redeclare package Medium = Medium) "Entrada freda (bypass del retorn)" annotation(
      Placement(transformation(extent = {{-10, -110}, {10, -90}})));
    Modelica.Fluid.Interfaces.FluidPort_b port_out(redeclare package Medium = Medium) "Sortida barrejada (impulsió)" annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    Modelica.Blocks.Interfaces.RealInput y "Obertura del pas calent (0-1)" annotation(
      Placement(transformation(extent = {{-20, -20}, {20, 20}}, rotation = -90, origin = {0, 120})));
    Real y_lim = min(max(y, 0), 1) "Obertura limitada";
  equation
// balanç de massa i repartiment de cabal (vàlvula ideal, sense pèrdua de càrrega)
    port_hot.m_flow + port_cold.m_flow + port_out.m_flow = 0;
    port_hot.m_flow = -y_lim*port_out.m_flow;
    port_hot.p = port_out.p;
// barreja ideal
    port_out.h_outflow = y_lim*inStream(port_hot.h_outflow) + (1 - y_lim)*inStream(port_cold.h_outflow);
    port_hot.h_outflow = inStream(port_out.h_outflow);
    port_cold.h_outflow = inStream(port_out.h_outflow);
    port_out.Xi_outflow = inStream(port_hot.Xi_outflow);
    port_hot.Xi_outflow = inStream(port_out.Xi_outflow);
    port_cold.Xi_outflow = inStream(port_out.Xi_outflow);
    port_out.C_outflow = inStream(port_hot.C_outflow);
    port_hot.C_outflow = inStream(port_out.C_outflow);
    port_cold.C_outflow = inStream(port_out.C_outflow);
    annotation(
      Icon(graphics = {Polygon(points = {{-90, 40}, {0, 0}, {-90, -40}, {-90, 40}}, lineColor = {0, 0, 0}, fillColor = {220, 60, 40}, fillPattern = FillPattern.Solid), Polygon(points = {{90, 40}, {0, 0}, {90, -40}, {90, 40}}, lineColor = {0, 0, 0}, fillColor = {255, 255, 255}, fillPattern = FillPattern.Solid), Polygon(points = {{-40, -90}, {0, 0}, {40, -90}, {-40, -90}}, lineColor = {0, 0, 0}, fillColor = {0, 118, 207}, fillPattern = FillPattern.Solid), Line(points = {{0, 0}, {0, 100}}, color = {0, 0, 127}), Text(extent = {{-150, 60}, {150, 90}}, textString = "%name", textColor = {0, 0, 255})}));
  end ThreeWayValve;

  model CoolingTower "Torre de refrigeració (aerorefrigerador sec): treu la calor que sobra quan el dipòsit és ple"
    replaceable package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater constrainedby Modelica.Media.Interfaces.PartialMedium "Aigua" annotation(
       choicesAllMatching = true);
    parameter Modelica.Units.SI.HeatFlowRate Q_max = 2.5e6 "Potència màxima de la torre";
    parameter Modelica.Units.SI.Temperature T_out_set = 328.15 "Termòstat: refreda l'aigua fins a aquesta T (55 °C)";
    parameter Modelica.Units.SI.Length length = 5 "Longitud del tub";
    parameter Modelica.Units.SI.Diameter diameter = 0.1 "Diàmetre del tub";
    Modelica.Fluid.Interfaces.FluidPort_a port_a(redeclare package Medium = Medium) "Entrada (aigua que surt de baix del dipòsit)" annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    Modelica.Fluid.Interfaces.FluidPort_b port_b(redeclare package Medium = Medium) "Sortida cap a la central" annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    Modelica.Blocks.Interfaces.RealOutput Q(unit = "W") "Calor rebutjada a l'exterior" annotation(
      Placement(transformation(extent = {{100, -70}, {120, -50}})));
    Modelica.Fluid.Pipes.DynamicPipe waterSide(redeclare package Medium = Medium, length = length, diameter = diameter, nNodes = 2, modelStructure = Modelica.Fluid.Types.ModelStructure.a_v_b, use_HeatTransfer = true, momentumDynamics = Modelica.Fluid.Types.Dynamics.SteadyState) annotation(
      Placement(transformation(extent = {{-10, -10}, {10, 10}})));
    Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow heat[2](each alpha = 0) "Calor repartida entre els 2 nodes del tub (v2: substitueix el ThermalCollector)" annotation(
      Placement(transformation(extent = {{-40, 50}, {-20, 70}})));
    Modelica.Units.SI.Temperature T_w_in "Termòmetre d'entrada (= aigua de baix del dipòsit)";
    Modelica.Units.SI.ThermalConductance C_w "Capacitat calorífica de l'aigua";
  equation
    T_w_in = Medium.temperature(Medium.setState_phX(port_a.p, inStream(port_a.h_outflow)));
    C_w = max(port_a.m_flow, 0)*Medium.specificHeatCapacityCp(Medium.setState_phX(port_a.p, inStream(port_a.h_outflow)));
// Control por temperatura de retorno: puede enfriar antes de que el depósito esté lleno.
    Q = min(Q_max, C_w*max(T_w_in - T_out_set, 0));
    heat.Q_flow = fill(-Q/2, 2);
    connect(heat.port, waterSide.heatPorts);
    connect(port_a, waterSide.port_a);
    connect(waterSide.port_b, port_b);
    annotation(
      Icon(graphics = {Polygon(points = {{-60, -80}, {-40, 60}, {40, 60}, {60, -80}, {-60, -80}}, lineColor = {0, 0, 0}, fillColor = {200, 200, 200}, fillPattern = FillPattern.Solid), Ellipse(extent = {{-30, 80}, {30, 50}}, lineColor = {0, 0, 0}, fillColor = {240, 240, 240}, fillPattern = FillPattern.Solid), Line(points = {{-20, 90}, {-10, 100}, {0, 90}, {10, 100}, {20, 90}}, color = {150, 150, 150}), Text(extent = {{-150, -85}, {150, -115}}, textString = "%name", textColor = {0, 0, 255})}));
  end CoolingTower;

  model BuildingDemand "Edifici provisional (fins que el grup Demand passi el seu): extreu Q_dem de l'aigua"
    replaceable package Medium = Modelica.Media.Water.ConstantPropertyLiquidWater constrainedby Modelica.Media.Interfaces.PartialMedium "Aigua" annotation(
       choicesAllMatching = true);
    parameter Modelica.Units.SI.Temperature T_r_design = 323.15 "Temperatura de retorn de disseny (50 °C)";
    parameter Modelica.Units.SI.Length length = 100 "Longitud equivalent de la instal·lació";
    parameter Modelica.Units.SI.Diameter diameter = 0.15 "Diàmetre equivalent";
    Modelica.Fluid.Interfaces.FluidPort_a port_a(redeclare package Medium = Medium) "Impulsió (T_s)" annotation(
      Placement(transformation(extent = {{-110, -10}, {-90, 10}})));
    Modelica.Fluid.Interfaces.FluidPort_b port_b(redeclare package Medium = Medium) "Retorn (T_r)" annotation(
      Placement(transformation(extent = {{90, -10}, {110, 10}})));
    Modelica.Blocks.Interfaces.RealInput Q_dem(unit = "W") "Demanda de calor" annotation(
      Placement(transformation(extent = {{-20, -20}, {20, 20}}, rotation = -90, origin = {0, 120})));
    Modelica.Blocks.Interfaces.RealOutput Q(unit = "W") "Calor entregada realment" annotation(
      Placement(transformation(extent = {{100, -70}, {120, -50}})));
    Modelica.Fluid.Pipes.DynamicPipe waterSide(redeclare package Medium = Medium, length = length, diameter = diameter, nNodes = 2, modelStructure = Modelica.Fluid.Types.ModelStructure.a_v_b, use_HeatTransfer = true, momentumDynamics = Modelica.Fluid.Types.Dynamics.SteadyState) annotation(
      Placement(transformation(extent = {{-10, -10}, {10, 10}})));
    Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow heat[2](each alpha = 0) "Calor repartida entre els 2 nodes del tub (v2: substitueix el ThermalCollector)" annotation(
      Placement(transformation(extent = {{-40, 50}, {-20, 70}})));
    Modelica.Units.SI.Temperature T_w_in "Temperatura d'impulsió que arriba";
    Modelica.Units.SI.HeatFlowRate Q_unmet "Demanda no coberta";
    Modelica.Units.SI.ThermalConductance C_w "Capacitat calorífica de l'aigua";
  equation
    T_w_in = Medium.temperature(Medium.setState_phX(port_a.p, inStream(port_a.h_outflow)));
    C_w = max(port_a.m_flow, 0)*Medium.specificHeatCapacityCp(Medium.setState_phX(port_a.p, inStream(port_a.h_outflow)));
// els emissors no poden refredar l'aigua per sota del retorn de disseny: si l'aigua arriba freda, no es cobreix tota la demanda
    Q = min(max(Q_dem, 0), C_w*max(T_w_in - T_r_design, 0));
    Q_unmet = max(Q_dem, 0) - Q;
    heat.Q_flow = fill(-Q/2, 2);
    connect(heat.port, waterSide.heatPorts);
    connect(port_a, waterSide.port_a);
    connect(waterSide.port_b, port_b);
    annotation(
      Icon(graphics = {Polygon(points = {{-70, 10}, {0, 80}, {70, 10}, {-70, 10}}, lineColor = {0, 0, 0}, fillColor = {200, 60, 40}, fillPattern = FillPattern.Solid), Rectangle(extent = {{-60, 10}, {60, -80}}, lineColor = {0, 0, 0}, fillColor = {255, 240, 200}, fillPattern = FillPattern.Solid), Rectangle(extent = {{-40, -10}, {-10, -40}}, lineColor = {0, 0, 0}, fillColor = {170, 213, 255}, fillPattern = FillPattern.Solid), Rectangle(extent = {{10, -10}, {40, -40}}, lineColor = {0, 0, 0}, fillColor = {170, 213, 255}, fillPattern = FillPattern.Solid), Text(extent = {{-150, -85}, {150, -115}}, textString = "%name", textColor = {0, 0, 255})}));
  end BuildingDemand;

  block DemandaSinus "Demanda de prova: sinusoide diària amb hores a zero (perquè el dipòsit treballi)"
    parameter Modelica.Units.SI.HeatFlowRate Q_mean = 1.5e6 "Valor mitjà de la sinusoide";
    parameter Real A = 1.2 "Amplitud relativa (A > 1 -> hores sense demanda)";
    parameter Modelica.Units.SI.Time t_peak = 8*3600 "Hora de la punta";
    parameter Modelica.Units.SI.Time day = 86400;
    Modelica.Blocks.Interfaces.RealOutput Q(unit = "W") "Demanda de calor" annotation(
      Placement(transformation(extent = {{100, -10}, {120, 10}})));
  equation
    Q = max(0, Q_mean*(1 + A*cos(2*Modelica.Constants.pi*(time - t_peak)/day)));
    annotation(
      Icon(graphics = {Rectangle(extent = {{-100, 100}, {100, -100}}, lineColor = {0, 0, 127}, fillColor = {255, 255, 255}, fillPattern = FillPattern.Solid), Line(points = {{-80, -60}, {-60, -60}, {-40, 0}, {-20, 60}, {0, 0}, {20, -60}, {40, -60}, {60, 0}, {80, 60}}, color = {200, 30, 30}, thickness = 0.5), Text(extent = {{-150, 140}, {150, 105}}, textString = "%name", textColor = {0, 0, 255})}));
  end DemandaSinus;

  block Economics "Balanç econòmic: integra energies i les passa a euros (preus orientatius, a revisar)"
    parameter Real price_el = 80 "Preu de venda de l'electricitat [€/MWh]";
    parameter Real price_heat = 60 "Preu de venda de la calor [€/MWh]";
    parameter Real price_gas = 35 "Preu del gas natural [€/MWh PCI]";
    parameter Real price_CO2 = 70 "Preu dels drets d'emissió [€/t]";
    parameter Real EF = 0.202 "Factor d'emissió del gas natural [t CO2/MWh PCI]";
    Modelica.Blocks.Interfaces.RealInput P_el(unit = "W") "Electricitat venuda" annotation(
      Placement(transformation(extent = {{-140, 60}, {-100, 100}})));
    Modelica.Blocks.Interfaces.RealInput Q_fuel(unit = "W") "Potència del combustible" annotation(
      Placement(transformation(extent = {{-140, 20}, {-100, 60}})));
    Modelica.Blocks.Interfaces.RealInput Q_plant(unit = "W") "Calor produïda per la central" annotation(
      Placement(transformation(extent = {{-140, -20}, {-100, 20}})));
    Modelica.Blocks.Interfaces.RealInput Q_sold(unit = "W") "Calor venuda a l'edifici" annotation(
      Placement(transformation(extent = {{-140, -60}, {-100, -20}})));
    Modelica.Blocks.Interfaces.RealInput Q_tower(unit = "W") "Calor rebutjada a la torre" annotation(
      Placement(transformation(extent = {{-140, -100}, {-100, -60}})));
    Real E_el(start = 0, fixed = true, unit = "MWh") "Electricitat venuda";
    Real E_fuel(start = 0, fixed = true, unit = "MWh") "Combustible consumit";
    Real E_plant(start = 0, fixed = true, unit = "MWh") "Calor produïda";
    Real E_sold(start = 0, fixed = true, unit = "MWh") "Calor venuda";
    Real E_tower(start = 0, fixed = true, unit = "MWh") "Calor rebutjada";
    Real CO2(unit = "t") "Emissions";
    Real c_unit "Cost de produir 1 MWh (elec. o calor, repartiment per energia) [€/MWh]";
    Real cost_rejected(start = 0, fixed = true) "Diners perduts per la calor rebutjada [€]";
    Real income_el "Ingressos per electricitat [€]";
    Real income_heat "Ingressos per calor [€]";
    Real cost_fuel "Cost del gas [€]";
    Real cost_CO2 "Cost del CO2 [€]";
    Real profit "Marge d'operació (sense CAPEX ni O&M) [€]";
    Real f_rejected "Fracció de la calor produïda que es rebutja";
  equation
    der(E_el) = P_el/3.6e9;
    der(E_fuel) = Q_fuel/3.6e9;
    der(E_plant) = Q_plant/3.6e9;
    der(E_sold) = Q_sold/3.6e9;
    der(E_tower) = Q_tower/3.6e9;
    CO2 = EF*E_fuel;
    c_unit = (price_gas + EF*price_CO2)*Q_fuel/max(P_el + Q_plant, 1);
    der(cost_rejected) = c_unit*Q_tower/3.6e9;
    income_el = price_el*E_el;
    income_heat = price_heat*E_sold;
    cost_fuel = price_gas*E_fuel;
    cost_CO2 = price_CO2*CO2;
    profit = income_el + income_heat - cost_fuel - cost_CO2;
    f_rejected = E_tower/max(E_plant, 1e-6);
    annotation(
      Icon(graphics = {Rectangle(extent = {{-100, 100}, {100, -100}}, lineColor = {0, 0, 127}, fillColor = {255, 255, 220}, fillPattern = FillPattern.Solid), Text(extent = {{-80, 60}, {80, -60}}, textString = "€"), Text(extent = {{-150, 140}, {150, 105}}, textString = "%name", textColor = {0, 0, 255})}));
  end Economics;

  model WeatherProfile "Model del professor (corregit: faltava import SI). T exterior i radiació solar"
    import SI = Modelica.Units.SI;
    parameter SI.Temperature TMean = 278.15 "Annual mean outdoor temperature";
    parameter SI.TemperatureDifference TDailyAmplitude = 5 "Daily outdoor-temperature swing";
    parameter SI.TemperatureDifference TSeasonAmplitude = 10 "Seasonal outdoor-temperature swing";
    parameter SI.Time year = 365*86400;
    parameter SI.Time day = 86400;
    output SI.Temperature TOutdoor "Outdoor dry-bulb temperature";
    output Real solarGain(unit = "W/m2") "Idealized global solar irradiance";
  equation
    TOutdoor = TMean + TSeasonAmplitude*cos(2*Modelica.Constants.pi*time/year) + TDailyAmplitude*cos(2*Modelica.Constants.pi*(time - 15*3600)/day);
    solarGain = 350*positivePart(sin(2*Modelica.Constants.pi*(time - 6*3600)/day));
    annotation(
      Icon(graphics = {Ellipse(extent = {{-70, 70}, {70, -70}}, lineColor = {220, 140, 0}, fillColor = {255, 220, 80}, fillPattern = FillPattern.Solid), Line(points = {{0, 100}, {0, 76}}, color = {220, 140, 0}, thickness = 2), Line(points = {{0, -76}, {0, -100}}, color = {220, 140, 0}, thickness = 2), Line(points = {{76, 0}, {100, 0}}, color = {220, 140, 0}, thickness = 2), Line(points = {{-76, 0}, {-100, 0}}, color = {220, 140, 0}, thickness = 2), Text(extent = {{-100, -82}, {100, -110}}, textString = "Weather")}));
  end WeatherProfile;

  // ======================================================================
  //  EXEMPLES (simular en aquest ordre)
  //   0. TestCicle         : v1 restaurat (només gas, 0,5 kg/s)
  //   1. TestCicleCombinat : cicle combinat a 2 MW amb aigua de prova
  //   2. TestDiposit       : dipòsit sol (càrrega / repòs / descàrrega)
  //   3. CentralCompleta   : tot junt, 3 dies, demanda sinusoidal
  // ======================================================================

  model TestCicle "v1 (només gas, 0,5 kg/s d'aire): C1 -> interrefrigerador -> C2 -> cambra -> turbina -> recuperador -> xemeneia"
    extends Modelica.Icons.Example;
    package Water = Modelica.Media.Water.ConstantPropertyLiquidWater;
    inner Modelica.Fluid.System system(energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial) annotation(
      Placement(transformation(extent = {{-100, 80}, {-80, 100}})));
    AirInlet air(m_air = 0.5) annotation(
      Placement(transformation(extent = {{-100, 20}, {-80, 40}})));
    Compressor C1(PR = 4, eta_is = 0.86) annotation(
      Placement(transformation(extent = {{-70, 20}, {-50, 40}})));
    Intercooler IC(eps = 0.8) annotation(
      Placement(transformation(extent = {{-40, 20}, {-20, 40}})));
    Compressor C2(PR = 4, eta_is = 0.86) annotation(
      Placement(transformation(extent = {{-10, 20}, {10, 40}})));
    CombustionChamber CC annotation(
      Placement(transformation(extent = {{20, 20}, {40, 40}})));
    Turbine T(eta_is = 0.89) annotation(
      Placement(transformation(extent = {{50, 20}, {70, 40}})));
    Generator G annotation(
      Placement(transformation(extent = {{80, -10}, {100, 10}})));
    Modelica.Blocks.Sources.Constant fuel(k = 0.0106) "Cabal de gas natural [kg/s]" annotation(
      Placement(transformation(extent = {{0, 60}, {20, 80}})));
    HeatRecovery HRSG(redeclare package Medium = Water, diameter = 0.05) annotation(
      Placement(transformation(extent = {{50, -40}, {70, -20}})));
    Chimney chimney annotation(
      Placement(transformation(extent = {{50, -80}, {70, -60}})));
    Modelica.Fluid.Sources.MassFlowSource_T waterIn(redeclare package Medium = Water, m_flow = 1.6, T = 318.15, nPorts = 1) "Retorn de la xarxa (45 °C)" annotation(
      Placement(transformation(extent = {{0, -40}, {20, -20}})));
    Modelica.Fluid.Sensors.TemperatureTwoPort T_s(redeclare package Medium = Water) annotation(
      Placement(transformation(extent = {{80, -40}, {100, -20}})));
    Modelica.Fluid.Sources.Boundary_pT waterOut(redeclare package Medium = Water, p = 2e5, nPorts = 1) annotation(
      Placement(transformation(extent = {{130, -40}, {110, -20}})));
    Real eta_el = G.P_el/max(CC.Q_fuel, 1) "Rendiment elèctric";
    Real eta_th = HRSG.Q/max(CC.Q_fuel, 1) "Rendiment tèrmic";
    Real eta_global = eta_el + eta_th "Rendiment global";
  equation
    connect(air.outlet, C1.inlet) annotation(Line(points = {{-80, 30}, {-70, 30}}, color = {0, 128, 255}));
    connect(C1.outlet, IC.inlet) annotation(Line(points = {{-50, 30}, {-40, 30}}, color = {0, 128, 255}));
    connect(IC.outlet, C2.inlet) annotation(Line(points = {{-20, 30}, {-10, 30}}, color = {0, 128, 255}));
    connect(C2.outlet, CC.inlet) annotation(Line(points = {{10, 30}, {20, 30}}, color = {0, 128, 255}));
    connect(CC.outlet, T.inlet) annotation(Line(points = {{40, 30}, {50, 30}}, color = {0, 128, 255}));
    connect(T.outlet, HRSG.gasIn) annotation(Line(points = {{70, 30}, {74, 30}, {74, -10}, {60, -10}, {60, -20}}, color = {0, 128, 255}));
    connect(HRSG.gasOut, chimney.inlet) annotation(Line(points = {{60, -40}, {60, -60}}, color = {0, 128, 255}));
    connect(fuel.y, CC.m_fuel) annotation(Line(points = {{21, 70}, {30, 70}, {30, 42}}, color = {0, 0, 127}));
    connect(T.W, G.W_turb) annotation(Line(points = {{60, 19}, {60, 6}, {78, 6}}, color = {0, 0, 127}));
    connect(C1.W, G.W_comp1) annotation(Line(points = {{-60, 19}, {-60, 0}, {78, 0}}, color = {0, 0, 127}));
    connect(C2.W, G.W_comp2) annotation(Line(points = {{0, 19}, {0, -6}, {78, -6}}, color = {0, 0, 127}));
    connect(waterIn.ports[1], HRSG.port_a) annotation(Line(points = {{20, -30}, {50, -30}}, color = {0, 127, 255}));
    connect(HRSG.port_b, T_s.port_a) annotation(Line(points = {{70, -30}, {80, -30}}, color = {0, 127, 255}));
    connect(T_s.port_b, waterOut.ports[1]) annotation(Line(points = {{100, -30}, {110, -30}}, color = {0, 127, 255}));
    annotation(
      experiment(StopTime = 3600, Interval = 10));
  end TestCicle;

  model TestCicleCombinat "Pas 1: cicle combinat sol (gas + vapor) amb aigua de prova a 50 °C i 12,2 kg/s"
    extends Modelica.Icons.Example;
    package Water = Modelica.Media.Water.ConstantPropertyLiquidWater;
    inner Modelica.Fluid.System system(energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial) annotation(
      Placement(transformation(extent = {{-115, 75}, {-95, 95}})));
    AirInlet air(m_air = 5) annotation(
      Placement(transformation(extent = {{-110, 50}, {-90, 70}})));
    Compressor C1(PR = 4, eta_is = 0.86) annotation(
      Placement(transformation(extent = {{-75, 50}, {-55, 70}})));
    Intercooler IC(eps = 0.8) annotation(
      Placement(transformation(extent = {{-40, 50}, {-20, 70}})));
    Compressor C2(PR = 4, eta_is = 0.86) annotation(
      Placement(transformation(extent = {{-5, 50}, {15, 70}})));
    CombustionChamber CC annotation(
      Placement(transformation(extent = {{30, 50}, {50, 70}})));
    Turbine T(eta_is = 0.89) annotation(
      Placement(transformation(extent = {{65, 50}, {85, 70}})));
    Modelica.Blocks.Sources.Constant fuel(k = 0.106) "Cabal de gas natural [kg/s] (x10 respecte a la v1)" annotation(
      Placement(transformation(extent = {{0, 85}, {20, 105}})));
    SteamGenerator HRSG(p_steam = 20e5, T_steam = 723.15, dT_pinch = 10) annotation(
      Placement(transformation(extent = {{65, -5}, {85, 25}})));
    SteamTurbine ST(eta_is = 0.80, T_cond = 373.15) annotation(
      Placement(transformation(extent = {{105, 6}, {125, 26}})));
    CondenserDH cond(redeclare package Medium = Water) annotation(
      Placement(transformation(extent = {{145, -20}, {165, 0}})));
    FeedPump FP(p_out = 20e5, eta = 0.75) annotation(
      Placement(transformation(extent = {{105, -40}, {125, -20}})));
    HeatRecovery ECO(redeclare package Medium = Water) "Economitzador de xarxa (8)" annotation(
      Placement(transformation(extent = {{65, -60}, {85, -40}})));
    Chimney chimney annotation(
      Placement(transformation(extent = {{65, -100}, {85, -80}})));
    GeneratorCC G annotation(
      Placement(transformation(extent = {{140, 50}, {160, 70}})));
    Modelica.Fluid.Sources.MassFlowSource_T waterIn(redeclare package Medium = Water, m_flow = 12.2, T = 323.15, nPorts = 1) "Retorn de la xarxa (50 °C)" annotation(
      Placement(transformation(extent = {{20, -60}, {40, -40}})));
    Modelica.Fluid.Sensors.TemperatureTwoPort T_s(redeclare package Medium = Water) "Impulsió" annotation(
      Placement(transformation(extent = {{140, -20}, {160, 0}})));
    Modelica.Fluid.Sources.Boundary_pT waterOut(redeclare package Medium = Water, p = 2e5, nPorts = 1) annotation(
      Placement(transformation(extent = {{175, -50}, {195, -30}})));
    Real eta_el = G.P_el/max(CC.Q_fuel, 1) "Rendiment elèctric";
    Real eta_th = (ECO.Q + cond.Q)/max(CC.Q_fuel, 1) "Rendiment tèrmic (calor a la xarxa)";
    Real eta_global = eta_el + eta_th "Rendiment global";
    Modelica.Units.SI.HeatFlowRate Q_plant = ECO.Q + cond.Q "Calor de la central a la xarxa (P_q2 + P_q3)";
  equation
    connect(air.outlet, C1.inlet) annotation(
      Line(points = {{-90, 60}, {-75, 60}}, color = {0, 128, 255}));
    connect(C1.outlet, IC.inlet) annotation(
      Line(points = {{-55, 60}, {-40, 60}}, color = {0, 128, 255}));
    connect(IC.outlet, C2.inlet) annotation(
      Line(points = {{-20, 60}, {-5, 60}}, color = {0, 128, 255}));
    connect(C2.outlet, CC.inlet) annotation(
      Line(points = {{15, 60}, {30, 60}}, color = {0, 128, 255}));
    connect(CC.outlet, T.inlet) annotation(
      Line(points = {{50, 60}, {65, 60}}, color = {0, 128, 255}));
    connect(fuel.y, CC.m_fuel) annotation(
      Line(points = {{21, 95}, {30.5, 95}, {30.5, 72}, {40, 72}}, color = {0, 0, 127}));
    connect(T.outlet, HRSG.gasIn) annotation(
      Line(points = {{85, 60}, {80, 60}, {80, 25}, {75, 25}}, color = {0, 128, 255}));
    connect(HRSG.gasOut, ECO.gasIn) annotation(
      Line(points = {{75, -5}, {75, -40}}, color = {0, 128, 255}));
    connect(ECO.gasOut, chimney.inlet) annotation(
      Line(points = {{75, -60}, {75, -80}}, color = {0, 128, 255}));
    connect(HRSG.steamOut, ST.inlet) annotation(
      Line(points = {{85, 16}, {105, 16}}, color = {128, 0, 128}));
    connect(ST.outlet, cond.inlet) annotation(
      Line(points = {{125, 16}, {140, 16}, {140, 0}, {155, 0}}, color = {128, 0, 128}));
    connect(cond.outlet, FP.inlet) annotation(
      Line(points = {{155, -20}, {130, -20}, {130, -30}, {105, -30}}, color = {128, 0, 128}));
    connect(FP.outlet, HRSG.feedIn) annotation(
      Line(points = {{125, -30}, {105, -30}, {105, 4}, {85, 4}}, color = {128, 0, 128}));
    connect(ECO.port_b, cond.port_a) annotation(
      Line(points = {{85, -50}, {115, -50}, {115, -10}, {145, -10}}, color = {0, 127, 255}));
    connect(T.W, G.W_turb) annotation(
      Line(points = {{75, 49}, {106.5, 49}, {106.5, 68}, {138, 68}}, color = {0, 0, 127}));
    connect(C1.W, G.W_comp1) annotation(
      Line(points = {{-65, 49}, {36.5, 49}, {36.5, 64}, {138, 64}}, color = {0, 0, 127}));
    connect(C2.W, G.W_comp2) annotation(
      Line(points = {{5, 49}, {71.5, 49}, {71.5, 60}, {138, 60}}, color = {0, 0, 127}));
    connect(ST.W, G.W_st) annotation(
      Line(points = {{115, 5}, {126.5, 5}, {126.5, 56}, {138, 56}}, color = {0, 0, 127}));
    connect(FP.W, G.W_pump) annotation(
      Line(points = {{115, -41}, {126.5, -41}, {126.5, 52}, {138, 52}}, color = {0, 0, 127}));
    connect(waterIn.ports[1], ECO.port_a) annotation(
      Line(points = {{40, -50}, {65, -50}}, color = {0, 127, 255}));
    connect(cond.port_b, T_s.port_a) annotation(
      Line(points = {{165, -10}, {140, -10}}, color = {0, 127, 255}));
    connect(T_s.port_b, waterOut.ports[1]) annotation(
      Line(points = {{160, -10}, {177.5, -10}, {177.5, -40}, {195, -40}}, color = {0, 127, 255}));
    annotation(
      experiment(StartTime = 0, StopTime = 3600, Tolerance = 1e-06, Interval = 10),
      Diagram(coordinateSystem(extent = {{-120, -120}, {200, 100}})));
  end TestCicleCombinat;

  model TestDiposit "Pas 2: dipòsit sol. Càrrega a 90 °C (0-8 h), repòs, descàrrega amb retorn a 50 °C (12-20 h)"
    extends Modelica.Icons.Example;
    package Water = Modelica.Media.Water.ConstantPropertyLiquidWater;
    inner Modelica.Fluid.System system(energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial) annotation(
      Placement(transformation(extent = {{-90, 70}, {-70, 90}})));
    Modelica.Blocks.Sources.CombiTimeTable profile(table = [0, 10; 8*3600, 10; 8*3600 + 60, 0; 12*3600, 0; 12*3600 + 60, -10; 20*3600, -10; 20*3600 + 60, 0; 24*3600, 0]) "Cabal [kg/s]: + entra a 90 °C per dalt, - surt per dalt cap a la xarxa" annotation(
      Placement(transformation(extent = {{-80, 30}, {-60, 50}})));
    Modelica.Fluid.Sources.MassFlowSource_T hot(redeclare package Medium = Water, use_m_flow_in = true, T = 363.15, nPorts = 1) "Central (90 °C) / sortida cap a la xarxa" annotation(
      Placement(transformation(extent = {{-30, 30}, {-10, 50}})));
    StratifiedTank tank(redeclare package Medium = Water, T_start = 323.15) annotation(
      Placement(transformation(extent = {{20, -20}, {40, 20}})));
    Modelica.Fluid.Sources.Boundary_pT ref(redeclare package Medium = Water, p = 3e5, T = 323.15, nPorts = 1) "Retorn de la xarxa a 50 °C + referència de pressió" annotation(
      Placement(transformation(extent = {{-30, -60}, {-10, -40}})));
  equation
    connect(profile.y[1], hot.m_flow_in) annotation(
      Line(points = {{-59, 40}, {-45.5, 40}, {-45.5, 48}, {-32, 48}}, color = {0, 0, 127}));
    connect(hot.ports[1], tank.port_top) annotation(
      Line(points = {{-10, 40}, {10, 40}, {10, 20}, {30, 20}}, color = {0, 127, 255}));
    connect(ref.ports[1], tank.port_bot) annotation(
      Line(points = {{-10, -50}, {10, -50}, {10, -20}, {30, -20}}, color = {0, 127, 255}));
    annotation(
      experiment(StartTime = 0, StopTime = 86400, Tolerance = 1e-06, Interval = 60),
      Diagram(coordinateSystem(extent = {{-100, -100}, {100, 100}})));
  end TestDiposit;

  model CentralCompleta "Pas 3: central completa 24 h/dia: cicle combinat -> dipòsit -> vàlvula 3 vies -> edifici; torre quan el dipòsit és ple"
    extends Modelica.Icons.Example;
    package Water = Modelica.Media.Water.ConstantPropertyLiquidWater;
    parameter Modelica.Units.SI.Temperature T_set = 358.15 "Consigna d'impulsió a l'edifici (85 °C)";
    inner Modelica.Fluid.System system(energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial, p_start = 3e5) annotation(
      Placement(transformation(extent = {{-115, 95}, {-95, 115}})));
    AirInlet air(m_air = 5) annotation(
      Placement(transformation(extent = {{-110, 70}, {-90, 90}})));
    Compressor C1(PR = 4, eta_is = 0.86) annotation(
      Placement(transformation(extent = {{-75, 70}, {-55, 90}})));
    Intercooler IC(eps = 0.8) annotation(
      Placement(transformation(extent = {{-40, 70}, {-20, 90}})));
    Compressor C2(PR = 4, eta_is = 0.86) annotation(
      Placement(transformation(extent = {{-5, 70}, {15, 90}})));
    CombustionChamber CC annotation(
      Placement(transformation(extent = {{30, 70}, {50, 90}})));
    Turbine T(eta_is = 0.89) annotation(
      Placement(transformation(extent = {{65, 70}, {85, 90}})));
    Modelica.Blocks.Sources.Constant fuel(k = 0.106) "Cabal de gas natural [kg/s] (x10 respecte a la v1)" annotation(
      Placement(transformation(extent = {{0, 105}, {20, 125}})));
    SteamGenerator HRSG(p_steam = 20e5, T_steam = 723.15, dT_pinch = 10) annotation(
      Placement(transformation(extent = {{65, 15}, {85, 45}})));
    SteamTurbine ST(eta_is = 0.80, T_cond = 373.15) annotation(
      Placement(transformation(extent = {{105, 26}, {125, 46}})));
    CondenserDH cond(redeclare package Medium = Water) annotation(
      Placement(transformation(extent = {{145, 0}, {165, 20}})));
    FeedPump FP(p_out = 20e5, eta = 0.75) annotation(
      Placement(transformation(extent = {{105, -20}, {125, 0}})));
    HeatRecovery ECO(redeclare package Medium = Water) "Economitzador de xarxa (8)" annotation(
      Placement(transformation(extent = {{65, -40}, {85, -20}})));
    Chimney chimney annotation(
      Placement(transformation(extent = {{65, -80}, {85, -60}})));
    GeneratorCC G annotation(
      Placement(transformation(extent = {{140, 70}, {160, 90}})));
    StratifiedTank tank(redeclare package Medium = Water, V = 200, H = 12, nSeg = 10, T_start = 343.15) annotation(
      Placement(transformation(extent = {{190, -20}, {210, 20}})));
    IdealPump pumpPlant(redeclare package Medium = Water) "Bomba del circuit de la central" annotation(
      Placement(transformation(extent = {{130, -120}, {150, -100}})));
    Modelica.Blocks.Sources.Constant mPlant(k = 12.2) "Cabal de la central [kg/s]: 2 MW amb ΔT = 40 K" annotation(
      Placement(transformation(extent = {{105, -95}, {125, -75}})));
    CoolingTower tower(redeclare package Medium = Water, Q_max = 2.5e6, T_out_set = 328.15) annotation(
      Placement(transformation(extent = {{50, -120}, {70, -100}})));
    Modelica.Fluid.Sources.Boundary_pT ref(redeclare package Medium = Water, p = 3e5, T = 323.15, nPorts = 1) "Única referència de pressió del circuit (vas d'expansió)" annotation(
      Placement(transformation(extent = {{230, -70}, {250, -50}})));
    ThreeWayValve valve(redeclare package Medium = Water) "Vàlvula de 3 vies de barreja" annotation(
      Placement(transformation(extent = {{230, 30}, {250, 50}})));
    Modelica.Fluid.Sensors.TemperatureTwoPort T_sup(redeclare package Medium = Water) "Termòmetre d'impulsió a l'edifici" annotation(
      Placement(transformation(extent = {{260, 30}, {280, 50}})));
    IdealPump pumpDem(redeclare package Medium = Water) "Bomba de la xarxa" annotation(
      Placement(transformation(extent = {{260, -10}, {280, 10}})));
    BuildingDemand building(redeclare package Medium = Water, T_r_design = 323.15) annotation(
      Placement(transformation(extent = {{260, -50}, {280, -30}})));
    Modelica.Fluid.Sensors.TemperatureTwoPort T_ret(redeclare package Medium = Water) "Termòmetre de retorn" annotation(
      Placement(transformation(extent = {{230, -30}, {250, -10}})));
    DemandaSinus demand(Q_mean = 1.5e6, A = 1.2, t_peak = 8*3600) "Demanda de prova (substituir pel grup Demand)" annotation(
      Placement(transformation(extent = {{280, 85}, {300, 105}})));
    Modelica.Blocks.Sources.RealExpression mDem(y = demand.Q/(4184*(T_set - building.T_r_design)) + 0.2) "Cabal de la xarxa per a ΔT de disseny" annotation(
      Placement(transformation(extent = {{230, 0}, {250, 20}})));
    Modelica.Blocks.Sources.Constant setT(k = T_set) "Consigna d'impulsió" annotation(
      Placement(transformation(extent = {{190, 75}, {210, 95}})));
    Modelica.Blocks.Continuous.LimPID PID(controllerType = Modelica.Blocks.Types.SimpleController.PI, k = 0.05, Ti = 60, yMax = 1, yMin = 0, initType = Modelica.Blocks.Types.Init.InitialOutput, y_start = 0.8) "Regulació de la T d'impulsió" annotation(
      Placement(transformation(extent = {{230, 75}, {250, 95}})));
    Modelica.Blocks.Logical.Hysteresis full(uLow = 333.15, uHigh = 343.15) "Senyal dipòsit ple (termòmetre de baix > 70 °C) per al grup de Control" annotation(
      Placement(transformation(extent = {{225, -105}, {245, -85}})));
    Economics econ annotation(
      Placement(transformation(extent = {{20, -150}, {40, -130}})));
    Real eta_el = G.P_el/max(CC.Q_fuel, 1) "Rendiment elèctric";
    Real eta_th = (ECO.Q + cond.Q)/max(CC.Q_fuel, 1) "Rendiment tèrmic (calor a la xarxa)";
    Real eta_global = eta_el + eta_th "Rendiment global";
    Modelica.Units.SI.HeatFlowRate Q_plant = ECO.Q + cond.Q "Calor de la central a la xarxa (P_q2 + P_q3)";
    Modelica.Units.SI.HeatFlowRate Q_dem = demand.Q "Demanda de l'edifici";
    Modelica.Units.SI.HeatFlowRate Q_served = building.Q "Calor entregada a l'edifici";
    Modelica.Units.SI.HeatFlowRate Q_tower = tower.Q "Calor rebutjada";
    Modelica.Units.SI.HeatFlowRate Q_tank = Q_plant - tower.Q - Q_served - tank.Q_loss "Càrrega (+) / descàrrega (-) del dipòsit (aprox.)";
    Real SOC = tank.SOC "Estat de càrrega del dipòsit";
    Boolean tankWarmReturn = full.y "Señal original de retorno caliente (histéresis 60/70 °C); no equivale a depósito lleno";
    Modelica.Units.SI.Energy E_capacity_useful = tank.E_capacity "Capacidad térmica útil entre las referencias Tmin y Tmax";
    Modelica.Units.SI.Energy E_tank_useful = tank.E_useful "Energía útil por capa; excluye el calentamiento por encima de Tmax";
    EnergyUseMonitor performance "Medidas de aprovechamiento y estados del depósito y la torre" annotation(Placement(transformation(extent = {{315, 50}, {335, 70}})));
    Real eta_useful = performance.eta_useful "Aprovechamiento energético instantáneo";
    Real eta_useful_accum = performance.eta_useful_accum "Aprovechamiento energético acumulado desde el inicio";
    Real SOC_useful = performance.SOC_useful "SOC acotado calculado con la energía útil de cada capa";
    Boolean tankFull = performance.tankFull "Depósito prácticamente lleno";
    Boolean towerActive = performance.towerActive "Rechazo térmico apreciable en la torre";
    Boolean fullAndCooling = performance.fullAndCooling "Depósito lleno y torre activa";
    Modelica.Units.SI.Temperature T_tower_out = Water.temperature(Water.setState_phX(tower.port_b.p, tower.port_b.h_outflow)) "Temperatura real de salida de la torre";
    Modelica.Units.SI.Power Q_tower_from_ports = -sum(tower.waterSide.heatPorts.Q_flow) "Calor que se extrae del agua por los puertos térmicos";
  equation
    performance.P_el = G.P_el;
    performance.Q_fuel = CC.Q_fuel;
    performance.Q_generated = ECO.Q + cond.Q;
    performance.Q_delivered = building.Q;
    performance.Q_rejected = tower.Q;
    performance.E_tank_useful = E_tank_useful;
    performance.E_capacity = E_capacity_useful;
    performance.T_layer_max = max(tank.T_layers);
    performance.T_limit = tank.T_max;
    performance.P_storage_useful = tank.P_useful;
    econ.Q_plant = Q_plant;
    connect(air.outlet, C1.inlet) annotation(
      Line(points = {{-90, 80}, {-75, 80}}, color = {0, 128, 255}));
    connect(C1.outlet, IC.inlet) annotation(
      Line(points = {{-55, 80}, {-40, 80}}, color = {0, 128, 255}));
    connect(IC.outlet, C2.inlet) annotation(
      Line(points = {{-20, 80}, {-5, 80}}, color = {0, 128, 255}));
    connect(C2.outlet, CC.inlet) annotation(
      Line(points = {{15, 80}, {30, 80}}, color = {0, 128, 255}));
    connect(CC.outlet, T.inlet) annotation(
      Line(points = {{50, 80}, {65, 80}}, color = {0, 128, 255}));
    connect(fuel.y, CC.m_fuel) annotation(
      Line(points = {{21, 115}, {30.5, 115}, {30.5, 92}, {40, 92}}, color = {0, 0, 127}));
    connect(T.outlet, HRSG.gasIn) annotation(
      Line(points = {{85, 80}, {80, 80}, {80, 45}, {75, 45}}, color = {0, 128, 255}));
    connect(HRSG.gasOut, ECO.gasIn) annotation(
      Line(points = {{75, 15}, {75, -20}}, color = {0, 128, 255}));
    connect(ECO.gasOut, chimney.inlet) annotation(
      Line(points = {{75, -40}, {75, -60}}, color = {0, 128, 255}));
    connect(HRSG.steamOut, ST.inlet) annotation(
      Line(points = {{85, 36}, {105, 36}}, color = {128, 0, 128}));
    connect(ST.outlet, cond.inlet) annotation(
      Line(points = {{125, 36}, {140, 36}, {140, 20}, {155, 20}}, color = {128, 0, 128}));
    connect(cond.outlet, FP.inlet) annotation(
      Line(points = {{155, 0}, {130, 0}, {130, -10}, {105, -10}}, color = {128, 0, 128}));
    connect(FP.outlet, HRSG.feedIn) annotation(
      Line(points = {{125, -10}, {105, -10}, {105, 24}, {85, 24}}, color = {128, 0, 128}));
    connect(ECO.port_b, cond.port_a) annotation(
      Line(points = {{85, -30}, {115, -30}, {115, 10}, {145, 10}}, color = {0, 127, 255}));
    connect(T.W, G.W_turb) annotation(
      Line(points = {{75, 69}, {106.5, 69}, {106.5, 88}, {138, 88}}, color = {0, 0, 127}));
    connect(C1.W, G.W_comp1) annotation(
      Line(points = {{-65, 69}, {36.5, 69}, {36.5, 84}, {138, 84}}, color = {0, 0, 127}));
    connect(C2.W, G.W_comp2) annotation(
      Line(points = {{5, 69}, {71.5, 69}, {71.5, 80}, {138, 80}}, color = {0, 0, 127}));
    connect(ST.W, G.W_st) annotation(
      Line(points = {{115, 25}, {126.5, 25}, {126.5, 76}, {138, 76}}, color = {0, 0, 127}));
    connect(FP.W, G.W_pump) annotation(
      Line(points = {{115, -21}, {126.5, -21}, {126.5, 72}, {138, 72}}, color = {0, 0, 127}));
    connect(tank.port_bot, pumpPlant.port_a) annotation(
      Line(points = {{200, -20}, {165, -20}, {165, -110}, {130, -110}}, color = {0, 127, 255}));
    connect(pumpPlant.port_b, tower.port_a) annotation(
      Line(points = {{150, -110}, {50, -110}}, color = {0, 127, 255}));
    connect(tower.port_b, ECO.port_a) annotation(
      Line(points = {{70, -110}, {67.5, -110}, {67.5, -30}, {65, -30}}, color = {0, 127, 255}));
    connect(cond.port_b, tank.port_top) annotation(
      Line(points = {{165, 10}, {182.5, 10}, {182.5, 20}, {200, 20}}, color = {0, 127, 255}));
    connect(mPlant.y, pumpPlant.m_flow_set) annotation(
      Line(points = {{126, -85}, {133, -85}, {133, -98}, {140, -98}}, color = {0, 0, 127}));
    connect(ref.ports[1], tank.port_bot) annotation(
      Line(points = {{250, -60}, {225, -60}, {225, -20}, {200, -20}}, color = {0, 127, 255}));
    connect(tank.port_top, valve.port_hot) annotation(
      Line(points = {{200, 20}, {215, 20}, {215, 40}, {230, 40}}, color = {0, 127, 255}));
    connect(valve.port_out, T_sup.port_a) annotation(
      Line(points = {{250, 40}, {260, 40}}, color = {0, 127, 255}));
    connect(T_sup.port_b, pumpDem.port_a) annotation(
      Line(points = {{280, 40}, {270, 40}, {270, 0}, {260, 0}}, color = {0, 127, 255}));
    connect(pumpDem.port_b, building.port_a) annotation(
      Line(points = {{280, 0}, {270, 0}, {270, -40}, {260, -40}}, color = {0, 127, 255}));
    connect(building.port_b, T_ret.port_a) annotation(
      Line(points = {{280, -40}, {255, -40}, {255, -20}, {230, -20}}, color = {0, 127, 255}));
    connect(T_ret.port_b, valve.port_cold) annotation(
      Line(points = {{250, -20}, {245, -20}, {245, 30}, {240, 30}}, color = {0, 127, 255}));
    connect(T_ret.port_b, tank.port_bot) annotation(
      Line(points = {{250, -20}, {200, -20}}, color = {0, 127, 255}));
    connect(demand.Q, building.Q_dem) annotation(
      Line(points = {{301, 95}, {285.5, 95}, {285.5, -28}, {270, -28}}, color = {0, 0, 127}));
    connect(mDem.y, pumpDem.m_flow_set) annotation(
      Line(points = {{251, 10}, {260.5, 10}, {260.5, 12}, {270, 12}}, color = {0, 0, 127}));
    connect(setT.y, PID.u_s) annotation(
      Line(points = {{211, 85}, {228, 85}}, color = {0, 0, 127}));
    connect(T_sup.T, PID.u_m) annotation(
      Line(points = {{270, 51}, {255, 51}, {255, 73}, {240, 73}}, color = {0, 0, 127}));
    connect(PID.y, valve.y) annotation(
      Line(points = {{251, 85}, {245.5, 85}, {245.5, 52}, {240, 52}}, color = {0, 0, 127}));
    connect(tank.T_bot, full.u) annotation(
      Line(points = {{211, -8}, {217, -8}, {217, -95}, {223, -95}}, color = {0, 0, 127}));
    connect(G.P_el, econ.P_el) annotation(
      Line(points = {{161, 80}, {89.5, 80}, {89.5, -132}, {18, -132}}, color = {0, 0, 127}));
    connect(CC.Q_fuel, econ.Q_fuel) annotation(
      Line(points = {{40, 69}, {29, 69}, {29, -136}, {18, -136}}, color = {0, 0, 127}));
    connect(building.Q, econ.Q_sold) annotation(
      Line(points = {{281, -46}, {149.5, -46}, {149.5, -144}, {18, -144}}, color = {0, 0, 127}));
    connect(tower.Q, econ.Q_tower) annotation(
      Line(points = {{71, -116}, {44.5, -116}, {44.5, -148}, {18, -148}}, color = {0, 0, 127}));
    annotation(
      experiment(StartTime = 0, StopTime = 259200, Tolerance = 1e-06, Interval = 60),
      Diagram(coordinateSystem(extent = {{-120, -160}, {300, 120}})));
  end CentralCompleta;
  model CicloCombinadoDeposito "Ciclo combinado conectado al depósito: ensayo de carga sin demanda"
    extends Modelica.Icons.Example;
    package Water = Modelica.Media.Water.ConstantPropertyLiquidWater;
    parameter Modelica.Units.SI.MassFlowRate m_air = 5 "Caudal de aire de la central";
    parameter Modelica.Units.SI.MassFlowRate m_fuel = 0.106 "Caudal de gas natural";
    parameter Modelica.Units.SI.MassFlowRate m_charge = 12.2 "Caudal de circulación entre central y depósito";
    parameter Modelica.Units.SI.AbsolutePressure p_steam = 20e5 "Presión de vapor vivo y de salida de la bomba de alimentación";
    parameter Modelica.Units.SI.Temperature T_steam = 723.15 "Temperatura del vapor vivo (450 °C)";
    parameter Modelica.Units.SI.Temperature T_cond = 373.15 "Temperatura de condensación del vapor (100 °C)";
    parameter Modelica.Units.SI.TemperatureDifference dT_pinch = 10 "Diferencia mínima gas-saturación en el evaporador";
    parameter Modelica.Units.SI.Volume V_tank = 200 "Volumen del depósito";
    parameter Modelica.Units.SI.Height H_tank = 12 "Altura del depósito";
    parameter Integer nSeg = 10 "Número de capas del depósito";
    parameter Modelica.Units.SI.CoefficientOfHeatTransfer U_tank = 0.3 "Coeficiente de pérdidas laterales del depósito";
    parameter Modelica.Units.SI.Temperature T_tank_start = 343.15 "Temperatura inicial uniforme del depósito (70 °C)";
    parameter Modelica.Units.SI.Temperature T_tank_min = 323.15 "Referencia inferior del SOC (50 °C)";
    parameter Modelica.Units.SI.Temperature T_tank_max = 363.15 "Referencia superior del SOC (90 °C); no es un limitador";
    parameter Modelica.Units.SI.Temperature T_ambient = 288.15 "Temperatura ambiente del depósito (15 °C)";
    parameter Modelica.Units.SI.AbsolutePressure p_network = 3e5 "Presión de referencia en el fondo del depósito";
    parameter Modelica.Units.SI.HeatFlowRate Q_tower_max = 2.5e6 "Potencia máxima de rechazo de la torre";
    parameter Modelica.Units.SI.Temperature T_tower_set = 328.15 "Consigna de enfriamiento de la torre (55 °C)";
    inner Modelica.Fluid.System system(energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial, p_start = p_network, T_start = T_tank_start) "Condiciones iniciales del circuito de agua" annotation(Placement(transformation(extent = {{-192, 98}, {-168, 122}})));
    AirInlet air(m_air = m_air) "Entrada de aire" annotation(Placement(transformation(extent = {{-192, 53}, {-168, 77}})));
    Compressor C1(PR = 4, eta_is = 0.86) "Primer compresor" annotation(Placement(transformation(extent = {{-147, 53}, {-123, 77}})));
    Intercooler IC(eps = 0.8) "Interrefrigerador" annotation(Placement(transformation(extent = {{-102, 53}, {-78, 77}})));
    Compressor C2(PR = 4, eta_is = 0.86) "Segundo compresor" annotation(Placement(transformation(extent = {{-57, 53}, {-33, 77}})));
    CombustionChamber CC "Cámara de combustión" annotation(Placement(transformation(extent = {{-12, 53}, {12, 77}})));
    Turbine GT(eta_is = 0.89) "Turbina de gas" annotation(Placement(transformation(extent = {{33, 53}, {57, 77}})));
    Modelica.Blocks.Sources.Constant fuel(k = m_fuel) "Consigna de combustible" annotation(Placement(transformation(extent = {{-12, 98}, {12, 122}})));
    SteamGenerator HRSG(p_steam = p_steam, T_steam = T_steam, dT_pinch = dT_pinch) "Caldera de recuperación" annotation(Placement(transformation(extent = {{78, -2}, {102, 22}})));
    SteamTurbine ST(eta_is = 0.80, T_cond = T_cond) "Turbina de vapor" annotation(Placement(transformation(extent = {{133, 23}, {157, 47}})));
    CondenserDH cond(redeclare package Medium = Water) "Condensador: intercambio de calor sin mezclar los fluidos" annotation(Placement(transformation(extent = {{188, -22}, {212, 2}})));
    FeedPump FP(p_out = p_steam, eta = 0.75) "Bomba de alimentación de la caldera" annotation(Placement(transformation(extent = {{133, -62}, {157, -38}})));
    HeatRecovery ECO(redeclare package Medium = Water) "Economizador de agua de la red" annotation(Placement(transformation(extent = {{78, -102}, {102, -78}})));
    Chimney chimney "Chimenea" annotation(Placement(transformation(extent = {{78, -152}, {102, -128}})));
    GeneratorCC G "Generador del ciclo combinado" annotation(Placement(transformation(extent = {{188, 88}, {212, 112}})));
    replaceable StratifiedTank tank(redeclare package Medium = Water, V = V_tank, H = H_tank, nSeg = nSeg, U = U_tank, T_start = T_tank_start, T_min = T_tank_min, T_max = T_tank_max, T_amb = T_ambient, p_bot_start = p_network) constrainedby StratifiedTank(redeclare package Medium = Water, V = V_tank, H = H_tank, nSeg = nSeg, U = U_tank, T_start = T_tank_start, T_min = T_tank_min, T_max = T_tank_max, T_amb = T_ambient, p_bot_start = p_network) "Depósito estratificado (replaceable: StratifiedTankHP añade la salida HeatPort)" annotation(Placement(transformation(extent = {{288, -22}, {312, 2}})));
    IdealPump pumpPlant(redeclare package Medium = Water) "Bomba de circulación del agua del depósito" annotation(Placement(transformation(extent = {{228, -122}, {252, -98}})));
    Modelica.Blocks.Sources.Constant mPlant(k = m_charge) "Consigna de caudal de carga" annotation(Placement(transformation(extent = {{228, -87}, {252, -63}})));
    CoolingTower tower(redeclare package Medium = Water, Q_max = Q_tower_max, T_out_set = T_tower_set) "Rechazo de calor por temperatura de retorno" annotation(Placement(transformation(extent = {{143, -122}, {167, -98}})));
    Modelica.Fluid.Sources.Boundary_pT ref(redeclare package Medium = Water, p = p_network, T = T_tank_start, nPorts = 1) "Única referencia de presión del circuito de agua" annotation(Placement(transformation(extent = {{338, -122}, {362, -98}})));
    Modelica.Fluid.Sensors.TemperatureTwoPort T_hot(redeclare package Medium = Water) "Temperatura real de entrada al depósito" annotation(Placement(transformation(extent = {{238, 8}, {262, 32}})));
    Modelica.Fluid.Sensors.TemperatureTwoPort T_cold(redeclare package Medium = Water) "Temperatura real de retorno desde el depósito" annotation(Placement(transformation(extent = {{288, -87}, {312, -63}})));
    Modelica.Units.SI.Power P_el = G.P_el "Potencia eléctrica neta; excluye auxiliares de circulación y torre";
    Modelica.Units.SI.HeatFlowRate Q_plant = ECO.Q + cond.Q "Potencia térmica total cedida al agua";
    Modelica.Units.SI.HeatFlowRate Q_rejected = tower.Q "Calor rechazado al ambiente por la torre";
    Modelica.Units.SI.HeatFlowRate Q_into_tank = tank.port_top.m_flow*actualStream(tank.port_top.h_outflow) + tank.port_bot.m_flow*actualStream(tank.port_bot.h_outflow) "Potencia neta de entalpía que entra al depósito por sus dos puertos";
    Modelica.Units.SI.HeatFlowRate Q_delivered = 0 "Calor entregado al consumidor (0 en este ensayo de carga; CentralHeatPort lo redefine)";
    Modelica.Units.SI.HeatFlowRate Q_storage = Q_into_tank - tank.Q_loss - Q_delivered "Potencia neta acumulada en el depósito; positiva en carga";
    Modelica.Units.SI.HeatFlowRate Q_balance_residual = der(tank.E_stored) - Q_storage "Residuo del balance de energía del depósito para este medio incompresible";
    Modelica.Units.SI.HeatFlowRate Q_aux_storage = Q_plant - Q_rejected - Q_into_tank "Acumulación transitoria en el agua de intercambiadores y torre";
    Modelica.Units.SI.Temperature T_supply = T_hot.T "Temperatura del agua que entra por arriba del depósito";
    Modelica.Units.SI.Temperature T_return = T_cold.T "Temperatura del agua que sale del fondo del depósito";
    Modelica.Units.SI.Temperature T_top = tank.T_top "Temperatura de la capa superior";
    Modelica.Units.SI.Temperature T_bottom = tank.T_bot "Temperatura de la capa inferior";
    Modelica.Units.SI.Energy E_stored = tank.E_stored "Energía útil respecto a T_tank_min";
    Real SOC = tank.SOC "Fracción de carga térmica; no limitada a 0..1";
    Real eta_el = G.P_el/max(CC.Q_fuel, 1) "Rendimiento eléctrico";
    Real eta_th = Q_plant/max(CC.Q_fuel, 1) "Rendimiento térmico bruto antes de torre y pérdidas";
    Real eta_global = eta_el + eta_th "Rendimiento de cogeneración bruto";
    Modelica.Units.SI.MassFlowRate m_reference = ref.ports[1].m_flow "Caudal en la referencia de presión; debe ser prácticamente nulo con agua incompresible";
    Boolean tankAboveReference = tank.T_top > T_tank_max "Indica que la capa superior supera la referencia de carga";
    Modelica.Units.SI.Energy E_capacity_useful = tank.E_capacity "Capacidad térmica útil entre las referencias Tmin y Tmax";
    Modelica.Units.SI.Energy E_tank_useful = tank.E_useful "Energía útil por capa; excluye el calentamiento por encima de Tmax";
    EnergyUseMonitor performance "Medidas de aprovechamiento y estados del depósito y la torre" annotation(Placement(transformation(extent = {{315, 50}, {335, 70}})));
    Real eta_useful = performance.eta_useful "Aprovechamiento energético instantáneo";
    Real eta_useful_accum = performance.eta_useful_accum "Aprovechamiento energético acumulado desde el inicio";
    Real SOC_useful = performance.SOC_useful "SOC acotado calculado con la energía útil de cada capa";
    Boolean tankFull = performance.tankFull "Depósito prácticamente lleno";
    Boolean towerActive = performance.towerActive "Rechazo térmico apreciable en la torre";
    Boolean fullAndCooling = performance.fullAndCooling "Depósito lleno y torre activa";
    Modelica.Units.SI.Temperature T_tower_out = Water.temperature(Water.setState_phX(tower.port_b.p, tower.port_b.h_outflow)) "Temperatura real de salida de la torre";
    Modelica.Units.SI.Power Q_tower_from_ports = -sum(tower.waterSide.heatPorts.Q_flow) "Calor que se extrae del agua por los puertos térmicos";
  initial equation
    assert(m_charge > 0, "m_charge debe ser positivo");
    assert(nSeg >= 2 and V_tank > 0 and H_tank > 0, "Geometría del depósito no válida");
    assert(T_tank_max > T_tank_min, "T_tank_max debe superar T_tank_min");
    assert(T_tank_max < T_cond, "La referencia superior del depósito debe ser menor que la temperatura de condensación");
  equation
    performance.P_el = G.P_el;
    performance.Q_fuel = CC.Q_fuel;
    performance.Q_generated = ECO.Q + cond.Q;
    performance.Q_delivered = Q_delivered;
    performance.Q_rejected = tower.Q;
    performance.E_tank_useful = E_tank_useful;
    performance.E_capacity = E_capacity_useful;
    performance.T_layer_max = max(tank.T_layers);
    performance.T_limit = tank.T_max;
    performance.P_storage_useful = tank.P_useful;
    connect(air.outlet, C1.inlet) annotation(Line(points = {{-168, 65}, {-147, 65}, {-147, 65}}, color = {185, 114, 35}));
    connect(C1.outlet, IC.inlet) annotation(Line(points = {{-123, 65}, {-102, 65}, {-102, 65}}, color = {185, 114, 35}));
    connect(IC.outlet, C2.inlet) annotation(Line(points = {{-78, 65}, {-57, 65}, {-57, 65}}, color = {185, 114, 35}));
    connect(C2.outlet, CC.inlet) annotation(Line(points = {{-33, 65}, {-12, 65}, {-12, 65}}, color = {185, 114, 35}));
    connect(CC.outlet, GT.inlet) annotation(Line(points = {{12, 65}, {33, 65}, {33, 65}}, color = {185, 114, 35}));
    connect(fuel.y, CC.m_fuel) annotation(Line(points = {{13.2, 110}, {0, 110}, {0, 79.4}}, color = {90, 100, 115}));
    connect(GT.outlet, HRSG.gasIn) annotation(Line(points = {{57, 65}, {90, 65}, {90, 22}}, color = {185, 114, 35}));
    connect(HRSG.gasOut, ECO.gasIn) annotation(Line(points = {{90, -2}, {90, -2}, {90, -78}}, color = {185, 114, 35}));
    connect(ECO.gasOut, chimney.inlet) annotation(Line(points = {{90, -102}, {78, -102}, {78, -140}}, color = {185, 114, 35}));
    connect(HRSG.steamOut, ST.inlet) annotation(Line(points = {{102, 14.8}, {133, 14.8}, {133, 35}}, color = {133, 67, 163}));
    connect(ST.outlet, cond.inlet) annotation(Line(points = {{157, 35}, {200, 35}, {200, 2}}, color = {133, 67, 163}));
    connect(cond.outlet, FP.inlet) annotation(Line(points = {{200, -22}, {200, -65}, {130, -65}, {130, -50}, {133, -50}}, color = {133, 67, 163}));
    connect(FP.outlet, HRSG.feedIn) annotation(Line(points = {{157, -50}, {165, -50}, {165, -30}, {110, -30}, {110, 5.2}, {102, 5.2}}, color = {133, 67, 163}));
    connect(GT.W, G.W_turb) annotation(Line(points = {{45, 51.8}, {185.6, 51.8}, {185.6, 109.6}}, color = {90, 100, 115}));
    connect(C1.W, G.W_comp1) annotation(Line(points = {{-135, 51.8}, {185.6, 51.8}, {185.6, 104.8}}, color = {90, 100, 115}));
    connect(C2.W, G.W_comp2) annotation(Line(points = {{-45, 51.8}, {185.6, 51.8}, {185.6, 100}}, color = {90, 100, 115}));
    connect(ST.W, G.W_st) annotation(Line(points = {{145, 21.8}, {185.6, 21.8}, {185.6, 95.2}}, color = {90, 100, 115}));
    connect(FP.W, G.W_pump) annotation(Line(points = {{145, -63.2}, {185.6, -63.2}, {185.6, 90.4}}, color = {90, 100, 115}));
    connect(tank.port_bot, T_cold.port_a) annotation(Line(points = {{300, -22}, {288, -22}, {288, -75}}, color = {0, 118, 207}));
    connect(T_cold.port_b, pumpPlant.port_a) annotation(Line(points = {{312, -75}, {228, -75}, {228, -110}}, color = {0, 118, 207}));
    connect(pumpPlant.port_b, tower.port_a) annotation(Line(points = {{252, -110}, {260, -110}, {260, -135}, {135, -135}, {135, -110}, {143, -110}}, color = {0, 118, 207}));
    connect(tower.port_b, ECO.port_a) annotation(Line(points = {{167, -110}, {68, -110}, {68, -90}, {78, -90}}, color = {0, 118, 207}));
    connect(ECO.port_b, cond.port_a) annotation(Line(points = {{102, -90}, {185, -90}, {185, -10}, {188, -10}}, color = {0, 118, 207}));
    connect(cond.port_b, T_hot.port_a) annotation(Line(points = {{212, -10}, {238, -10}, {238, 20}}, color = {0, 118, 207}));
    connect(T_hot.port_b, tank.port_top) annotation(Line(points = {{262, 20}, {300, 20}, {300, 2}}, color = {0, 118, 207}));
    connect(mPlant.y, pumpPlant.m_flow_set) annotation(Line(points = {{253.2, -75}, {240, -75}, {240, -95.6}}, color = {90, 100, 115}));
    connect(ref.ports[1], tank.port_bot) annotation(Line(points = {{362, -110}, {300, -110}, {300, -22}}, color = {0, 118, 207}));
    annotation(
      experiment(StartTime = 0, StopTime = 86400, Tolerance = 1e-6, Interval = 60),
      Diagram(coordinateSystem(extent = {{-205, -165}, {380, 135}})),
      Documentation(info = "<html><p>Modelo de carga del depósito. Abrir y simular CicleGas2.CicloCombinadoDeposito.</p><p>Agua: fondo del depósito, bomba, torre, economizador, condensador, parte superior del depósito. Vapor: HRSG, turbina, condensador, bomba de alimentación, HRSG. Los fluidos no se mezclan.</p><p>Los parámetros son orientativos y proceden del archivo original. La torre enfría por temperatura de retorno, no por SOC. T_tank_max es una referencia, no un control de seguridad. Para carga y descarga con consumo, usar CentralCompleta.</p><p>Q_storage usa los flujos de entalpía de los puertos. Q_aux_storage distingue la acumulación en los intercambiadores del almacenamiento en el depósito. P_el no incluye consumos de las bombas ideales de red ni de la torre.</p><p>Verificación pendiente: compilación y simulación con Modelica Standard Library 4.0.0.</p></html>"));
  end CicloCombinadoDeposito;

  block EnergyUseMonitor "Aprovechamiento energético con contabilidad del almacenamiento"
    parameter Real SOC_full = 0.98 "Umbral de depósito prácticamente lleno";
    parameter Modelica.Units.SI.Power Q_tol = 1000 "Umbral para considerar una potencia despreciable";
    input Modelica.Units.SI.Power P_el "Electricidad neta del generador; auxiliares de red no incluidos";
    input Modelica.Units.SI.Power Q_fuel "Potencia química del combustible, PCI";
    input Modelica.Units.SI.Power Q_generated "Calor bruto cedido por condensador y economizador";
    input Modelica.Units.SI.Power Q_delivered "Calor realmente entregado a consumidores";
    input Modelica.Units.SI.Power Q_rejected "Calor disipado en la torre";
    input Modelica.Units.SI.Energy E_tank_useful "Energía del depósito acotada por capa entre Tmin y Tmax";
    input Modelica.Units.SI.Energy E_capacity "Capacidad útil total del depósito";
    input Modelica.Units.SI.Temperature T_layer_max "Máxima temperatura de las capas del depósito";
    input Modelica.Units.SI.Temperature T_limit "Temperatura máxima de referencia";
    input Modelica.Units.SI.Power P_storage_useful "Variación de la energía útil almacenada (= dE_tank_useful/dt), calculada sin der() de expresiones algebraicas";
    parameter Modelica.Units.SI.Energy E_initial(fixed = false) "Energía útil presente al iniciar el ensayo";
    Modelica.Units.SI.Energy E_el(start = 0, fixed = true) "Electricidad generada desde el inicio";
    Modelica.Units.SI.Energy E_fuel(start = 0, fixed = true) "Combustible consumido desde el inicio";
    Modelica.Units.SI.Energy E_delivered(start = 0, fixed = true) "Calor entregado desde el inicio";
    Modelica.Units.SI.Energy E_rejected(start = 0, fixed = true) "Calor disipado desde el inicio";
    Real SOC_useful "Fracción de la capacidad útil entre cero y uno";
    Real eta_el "Rendimiento eléctrico del ciclo";
    Real eta_gross "Electricidad y calor bruto antes de rechazo y pérdidas";
    Real eta_useful "Aprovechamiento instantáneo: electricidad, consumo y variación útil del depósito";
    Real eta_useful_accum "Aprovechamiento desde el inicio, descontando la energía inicial del depósito";
    Real f_rejected "Fracción instantánea del calor bruto rechazada a la torre";
    Boolean tankFull "SOC útil mayor o igual que el umbral de lleno";
    Boolean towerActive "La torre rechaza más de Q_tol";
    Boolean fullAndCooling "Depósito lleno y torre rechazando calor";
    Boolean coolingBeforeFull "La torre ya enfría antes de llenarse el depósito";
    Boolean fullWithoutCooling "Depósito lleno con calor generado, pero sin rechazo apreciable";
    Boolean overTemperature "Alguna capa supera la referencia máxima en más de 0,5 K";
    Boolean storageNearlySteady "La variación de energía útil almacenada es menor que Q_tol";
  initial equation
    E_initial = E_tank_useful;
    assert(SOC_full > 0 and SOC_full <= 1, "SOC_full debe estar entre cero y uno");
    assert(Q_tol > 0, "Q_tol debe ser positivo");
  equation
    der(E_el) = P_el;
    der(E_fuel) = Q_fuel;
    der(E_delivered) = Q_delivered;
    der(E_rejected) = Q_rejected;
    SOC_useful = E_tank_useful/max(E_capacity, 1);
    eta_el = if Q_fuel > Q_tol then P_el/Q_fuel else 0;
    eta_gross = if Q_fuel > Q_tol then (P_el + Q_generated)/Q_fuel else 0;
    eta_useful = if Q_fuel > Q_tol then (P_el + Q_delivered + P_storage_useful)/Q_fuel else 0;
    eta_useful_accum = if E_fuel > 1 then (E_el + E_delivered + E_tank_useful - E_initial)/E_fuel else 0;
    f_rejected = if Q_generated > Q_tol then Q_rejected/Q_generated else 0;
    tankFull = SOC_useful >= SOC_full;
    towerActive = Q_rejected > Q_tol;
    fullAndCooling = tankFull and towerActive;
    coolingBeforeFull = towerActive and not tankFull;
    fullWithoutCooling = tankFull and Q_generated > Q_tol and not towerActive;
    overTemperature = T_layer_max > T_limit + 0.5;
    storageNearlySteady = abs(P_storage_useful) < Q_tol;
    annotation(Documentation(info = "<html><p>Balance energético de primer principio ampliado al almacenamiento. P_storage_useful conserva el signo: no debe sustituirse por max(P_storage_useful,0), porque durante la descarga se contabilizaría dos veces la misma energía.</p><p>La energía útil se acota en cada capa para excluir sobretemperatura y energía por debajo de Tmin. eta_useful puede tener transitorios fuera del intervalo 0..1 por intercambios con otros volúmenes inicialmente calientes. eta_useful_accum corrige la energía inicial del depósito, pero requiere también atender al cambio de energía de los otros componentes al comparar intervalos cortos.</p><p>Este bloque observa la instalación; no cambia el control térmico de la torre. Sus señales no garantizan la suficiencia de refrigeración: deben revisarse simultáneamente Q_rejected y la evolución de todas las temperaturas.</p></html>"));
  end EnergyUseMonitor;

  model EnsayoDepositoFrio "Comparación: depósito inicialmente a 50 °C"
    extends CicloCombinadoDeposito(T_tank_start = 323.15);
    annotation(experiment(StopTime = 86400, Interval = 60, Tolerance = 1e-6));
  end EnsayoDepositoFrio;

  model EnsayoDepositoLleno "Comparación: depósito inicialmente a 90 °C"
    extends CicloCombinadoDeposito(T_tank_start = 363.15);
    annotation(experiment(StopTime = 86400, Interval = 60, Tolerance = 1e-6));
  end EnsayoDepositoLleno;

  model EnsayoPotencia125 "Escala orientativa de potencia al 125 por ciento"
    extends CicloCombinadoDeposito(m_air = 6.25, m_fuel = 0.1325, m_charge = 15.25, Q_tower_max = 3.125e6, T_tank_start = 323.15);
    annotation(experiment(StopTime = 86400, Interval = 60, Tolerance = 1e-6));
  end EnsayoPotencia125;

  // ======================================================================
  //  ENSAYOS DE LA SALIDA HEATPORT DEL DEPÓSITO
  //   A. TestDepositoHeatPort_Q : depósito solo (lleno a 90 °C), el consumidor impone Q (demanda inventada)
  //   B. TestDepositoHeatPort_T : depósito solo, el consumidor impone T (45 °C) y el caudal por señal
  //   C. CentralHeatPort        : ciclo combinado + depósito + torre + demanda inventada por el HeatPort
  // ======================================================================

  model TestDepositoHeatPort_Q "A: depósito solo con salida HeatPort; el consumidor impone la potencia (sinusoide con horas a cero)"
    extends Modelica.Icons.Example;
    package Water = Modelica.Media.Water.ConstantPropertyLiquidWater;
    parameter Modelica.Units.SI.Temperature T_tank_start = 363.15 "Depósito inicialmente lleno (90 °C)";
    inner Modelica.Fluid.System system(energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial, p_start = 3e5) annotation(
      Placement(transformation(extent = {{-90, 70}, {-70, 90}})));
    StratifiedTankHP tank(redeclare package Medium = Water, V = 200, H = 12, nSeg = 10, T_start = T_tank_start) annotation(
      Placement(transformation(extent = {{20, -20}, {40, 20}})));
    Modelica.Fluid.Sources.Boundary_pT ref(redeclare package Medium = Water, p = 3e5, T = 323.15, nPorts = 1) "Referencia de presión (vaso de expansión)" annotation(
      Placement(transformation(extent = {{80, -60}, {60, -40}})));
    DemandaSinus demand(Q_mean = 0.4e6, A = 1.2, t_peak = 8*3600) "Demanda inventada: 9,6 MWh/día ≈ capacidad del depósito" annotation(
      Placement(transformation(extent = {{-90, -10}, {-70, 10}})));
    Modelica.Blocks.Math.Gain neg(k = -1) "Q_flow < 0: el calor sale del depósito" annotation(
      Placement(transformation(extent = {{-60, -10}, {-40, 10}})));
    Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow consumer(alpha = 0) "Consumidor (sustituir por el modelo del grupo Demanda)" annotation(
      Placement(transformation(extent = {{-30, -10}, {-10, 10}})));
    Modelica.Units.SI.HeatFlowRate Q_dem = demand.Q "Potencia pedida";
    Modelica.Units.SI.HeatFlowRate Q_dis = tank.Q_dis "Potencia entregada por el HeatPort";
    Modelica.Units.SI.Temperature T_port = tank.heatPort_dis.T "T que devuelve el HeatPort al consumidor";
    Modelica.Units.SI.Temperature T_supply = tank.T_dis_supply "T de la capa de arriba (entrada al intercambiador)";
    Modelica.Units.SI.Temperature T_return = tank.T_dis_return "T con la que vuelve el agua al fondo";
    Modelica.Units.SI.MassFlowRate m_dis = tank.m_dis "Caudal de descarga";
    Real SOC_useful = tank.E_useful/tank.E_capacity "Estado de carga útil";
    Modelica.Units.SI.HeatFlowRate Q_balance_residual = der(tank.E_stored) + tank.Q_dis + tank.Q_loss "Debe ser ~0: dE/dt = -Q_dis - Q_loss";
  equation
    connect(demand.Q, neg.u) annotation(
      Line(points = {{-69, 0}, {-62, 0}}, color = {0, 0, 127}));
    connect(neg.y, consumer.Q_flow) annotation(
      Line(points = {{-39, 0}, {-30, 0}}, color = {0, 0, 127}));
    connect(consumer.port, tank.heatPort_dis) annotation(
      Line(points = {{-10, 0}, {20, 0}}, color = {191, 0, 0}));
    connect(ref.ports[1], tank.port_bot) annotation(
      Line(points = {{60, -50}, {30, -50}, {30, -20}}, color = {0, 127, 255}));
    annotation(
      experiment(StartTime = 0, StopTime = 86400, Tolerance = 1e-06, Interval = 60),
      Documentation(info = "<html><p>Sin carga desde la central. El depósito empieza lleno y se vacía con la demanda inventada. Ver Q_dis vs Q_dem, T_port, T_supply, T_return, m_dis y SOC_useful. Q_balance_residual comprueba el balance de energía.</p></html>"));
  end TestDepositoHeatPort_Q;

  model TestDepositoHeatPort_T "B: depósito solo; el consumidor impone su temperatura (45 °C) y el caudal de descarga va por señal"
    extends Modelica.Icons.Example;
    package Water = Modelica.Media.Water.ConstantPropertyLiquidWater;
    inner Modelica.Fluid.System system(energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial, p_start = 3e5) annotation(
      Placement(transformation(extent = {{-90, 70}, {-70, 90}})));
    StratifiedTankHP tank(redeclare package Medium = Water, V = 200, H = 12, nSeg = 10, T_start = 363.15, use_m_flow_in = true) annotation(
      Placement(transformation(extent = {{20, -20}, {40, 20}})));
    Modelica.Fluid.Sources.Boundary_pT ref(redeclare package Medium = Water, p = 3e5, T = 323.15, nPorts = 1) annotation(
      Placement(transformation(extent = {{80, -60}, {60, -40}})));
    Modelica.Thermal.HeatTransfer.Sources.FixedTemperature consumer(T = 318.15) "Consumidor a 45 °C (p. ej. secundario de la vivienda)" annotation(
      Placement(transformation(extent = {{-30, -10}, {-10, 10}})));
    Modelica.Blocks.Sources.CombiTimeTable mProfile(table = [0, 2; 6*3600, 2; 6*3600 + 60, 8; 9*3600, 8; 9*3600 + 60, 0; 17*3600, 0; 17*3600 + 60, 5; 22*3600, 5; 22*3600 + 60, 0; 24*3600, 0]) "Caudal de descarga inventado [kg/s]" annotation(
      Placement(transformation(extent = {{-90, -70}, {-70, -50}})));
    Modelica.Units.SI.HeatFlowRate Q_dis = tank.Q_dis "Potencia que resulta";
    Modelica.Units.SI.Temperature T_supply = tank.T_dis_supply;
    Modelica.Units.SI.Temperature T_return = tank.T_dis_return;
    Real SOC_useful = tank.E_useful/tank.E_capacity;
  equation
    connect(consumer.port, tank.heatPort_dis) annotation(
      Line(points = {{-10, 0}, {20, 0}}, color = {191, 0, 0}));
    connect(ref.ports[1], tank.port_bot) annotation(
      Line(points = {{60, -50}, {30, -50}, {30, -20}}, color = {0, 127, 255}));
    connect(mProfile.y[1], tank.m_dis_in) annotation(
      Line(points = {{-69, -60}, {0, -60}, {0, -12}, {18, -12}}, color = {0, 0, 127}));
    annotation(
      experiment(StartTime = 0, StopTime = 86400, Tolerance = 1e-06, Interval = 60));
  end TestDepositoHeatPort_T;

  model CentralHeatPort "C: ciclo combinado -> depósito -> salida HeatPort con demanda inventada; torre en el lazo de carga"
    extends CicloCombinadoDeposito(redeclare StratifiedTankHP tank, Q_delivered = tank.Q_dis);
    DemandaSinus demand(Q_mean = 1.0e6, A = 1.2, t_peak = 8*3600) "Demanda inventada: media 1 MW, punta 2,2 MW (< 2,5 MW = m_dis_max·cp·40 K). Con Q impuesto, una demanda mayor que central + depósito enfría el agua sin límite" annotation(
      Placement(transformation(extent = {{230, 40}, {250, 60}})));
    Modelica.Blocks.Math.Gain neg(k = -1) annotation(
      Placement(transformation(extent = {{260, 40}, {280, 60}})));
    Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow consumer(alpha = 0) "Consumidor por HeatPort" annotation(
      Placement(transformation(extent = {{290, 40}, {310, 60}})));
    Modelica.Units.SI.HeatFlowRate Q_dem = demand.Q "Demanda";
    Modelica.Units.SI.HeatFlowRate Q_dis = tank.Q_dis "Calor entregado por el HeatPort";
    Modelica.Units.SI.Temperature T_port = tank.heatPort_dis.T "T en el HeatPort";
    Modelica.Units.SI.Temperature T_dis_return = tank.T_dis_return "Retorno de la descarga al fondo";
    Modelica.Units.SI.MassFlowRate m_dis = tank.m_dis "Caudal de descarga";
  equation
    connect(demand.Q, neg.u) annotation(
      Line(points = {{251, 50}, {258, 50}}, color = {0, 0, 127}));
    connect(neg.y, consumer.Q_flow) annotation(
      Line(points = {{281, 50}, {290, 50}}, color = {0, 0, 127}));
    connect(consumer.port, tank.heatPort_dis) annotation(
      Line(points = {{310, 50}, {320, 50}, {320, 30}, {280, 30}, {280, -10}, {288, -10}}, color = {191, 0, 0}));
    annotation(
      experiment(StartTime = 0, StopTime = 259200, Tolerance = 1e-06, Interval = 60));
  end CentralHeatPort;

  annotation(
    uses(Modelica(version = "4.0.0")));
end CicleGas2;
