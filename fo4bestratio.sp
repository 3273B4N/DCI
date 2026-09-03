* Created: Fri Aug 11 13:47:14 2017
* Basado en ejemplo dado por Weste-Harris. Fig 8.10, 8.9. Cuarta edicion

* fo4.sp
*----------------------------------------------------------------------
* Parameters and models
*----------------------------------------------------------------------
* XT018, Low Power MOS, 1.8V
* Se incluye la biblioteca tipica de LP5MOS
* Ojo: verifiquen que apunten a donde esta instalado el PDK
.option search='/mnt/vol_synopsys2023/pdks/xfab/design/xkit/xh018/synopsys/v9_0/hspice/v9_0_2/lpmos'
*.option search='$DESING_HOME/tech_char/inv'
.lib './xh018.lib' tm
.lib './param.lib' 3s
.option PARHIER = LOCAL

.option ARTIST=2 PSF=2

.param SUPPLY=1.8
* Vamos a hacer una cadena FO4 (ver fig. 8.9 Weste-Harris)
.param H=3
* Estamos en largo minimo 180nm, Lambda=90nm
.option scale=90n 
*
.param PWidth = 5

.temp 70
.option post
*----------------------------------------------------------------------
* Subcircuits. Se incluye el inversor definido como subcomponente en inv.sp
*----------------------------------------------------------------------
.global vdd gnd
.subckt inv a y N=2.5 P=PWidth
xM1 y a gnd gnd ne W='N' L=2
+ AS='N*5' PS='2*N+10' AD='N*5' PD='2*N+10'
xM2 y a vdd vdd pe W='P' L=2
+ AS='P*5' PS='2*P+10' AD='P*5' PD='2*P+10'
.ends inv 

*----------------------------------------------------------------------
* Simulation netlist
*----------------------------------------------------------------------
Vdd vdd gnd 'SUPPLY'
Vin a gnd PULSE 0 'SUPPLY' 0ps 20ps 20ps 360ps 760ps
X1 a b inv * shape input waveform
X2 b c inv M='H' * reshape input waveform
X3 c d inv M='H**2' * device under test
X4 d e inv M='H**3' * load
X5 e f inv M='H**4' * load on load
*----------------------------------------------------------------------
* Stimulus
*----------------------------------------------------------------------
.tran 0.1ps 960ps *SWEEP PWidth 2.5 15 0.5
.measure tpdr * rising prop delay
+ TRIG v(c) VAL='SUPPLY/2' FALL=1
+ TARG v(d) VAL='SUPPLY/2' RISE=1
.measure tpdf * falling prop delay
+ TRIG v(c) VAL='SUPPLY/2' RISE=1
+ TARG v(d) VAL='SUPPLY/2' FALL=1
.measure tpd param='(tpdr+tpdf)/2' * average prop delay
.measure trise * rise time
+ TRIG v(d) VAL='0.2*SUPPLY' RISE=1
+ TARG v(d) VAL='0.8*SUPPLY' RISE=1
.measure tfall * fall time
+ TRIG v(d) VAL='0.8*SUPPLY' FALL=1
+ TARG v(d) VAL='0.2*SUPPLY' FALL=1
.end

