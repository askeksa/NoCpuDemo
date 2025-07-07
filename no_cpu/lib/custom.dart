// Relevant Amiga custom chip register addresses
const int VPOSW = 0x02A;
const int VHPOSW = 0x02C;
const int BLTCON0 = 0x040;
const int BLTCON1 = 0x042;
const int BLTAFWM = 0x044;
const int BLTALWM = 0x046;
const int BLTCPTH = 0x048;
const int BLTCPTL = 0x04A;
const int BLTBPTH = 0x04C;
const int BLTBPTL = 0x04E;
const int BLTAPTH = 0x050;
const int BLTAPTL = 0x052;
const int BLTDPTH = 0x054;
const int BLTDPTL = 0x056;
const int BLTSIZE = 0x058;
const int BLTCON0L = 0x05A;
const int BLTSIZV = 0x05C;
const int BLTSIZH = 0x05E;
const int BLTCMOD = 0x060;
const int BLTBMOD = 0x062;
const int BLTAMOD = 0x064;
const int BLTDMOD = 0x066;
const int BLTCDAT = 0x070;
const int BLTBDAT = 0x072;
const int BLTADAT = 0x074;
const int COP1LCH = 0x080;
const int COP1LCL = 0x082;
const int COP2LCH = 0x084;
const int COP2LCL = 0x086;
const int COPJMP1 = 0x088;
const int COPJMP2 = 0x08A;
const int DIWSTRT = 0x08E;
const int DIWSTOP = 0x090;
const int DDFSTRT = 0x092;
const int DDFSTOP = 0x094;
const int DMACON = 0x096;
const int ADKCON = 0x09E;
const int AUD0LCH = 0x0A0;
const int AUD0LCL = 0x0A2;
const int AUD0LEN = 0x0A4;
const int AUD0PER = 0x0A6;
const int AUD0VOL = 0x0A8;
const int AUD0DAT = 0x0AA;
const int AUD1LCH = 0x0B0;
const int AUD1LCL = 0x0B2;
const int AUD1LEN = 0x0B4;
const int AUD1PER = 0x0B6;
const int AUD1VOL = 0x0B8;
const int AUD1DAT = 0x0BA;
const int AUD2LCH = 0x0C0;
const int AUD2LCL = 0x0C2;
const int AUD2LEN = 0x0C4;
const int AUD2PER = 0x0C6;
const int AUD2VOL = 0x0C8;
const int AUD2DAT = 0x0CA;
const int AUD3LCH = 0x0D0;
const int AUD3LCL = 0x0D2;
const int AUD3LEN = 0x0D4;
const int AUD3PER = 0x0D6;
const int AUD3VOL = 0x0D8;
const int AUD3DAT = 0x0DA;
const int BPL1PTH = 0x0E0;
const int BPL1PTL = 0x0E2;
const int BPL2PTH = 0x0E4;
const int BPL2PTL = 0x0E6;
const int BPL3PTH = 0x0E8;
const int BPL3PTL = 0x0EA;
const int BPL4PTH = 0x0EC;
const int BPL4PTL = 0x0EE;
const int BPL5PTH = 0x0F0;
const int BPL5PTL = 0x0F2;
const int BPL6PTH = 0x0F4;
const int BPL6PTL = 0x0F6;
const int BPL7PTH = 0x0F8;
const int BPL7PTL = 0x0FA;
const int BPL8PTH = 0x0FC;
const int BPL8PTL = 0x0FE;
const int BPLCON0 = 0x100;
const int BPLCON1 = 0x102;
const int BPLCON2 = 0x104;
const int BPLCON3 = 0x106;
const int BPL1MOD = 0x108;
const int BPL2MOD = 0x10A;
const int BPLCON4 = 0x10C;
const int BPL1DAT = 0x110;
const int BPL2DAT = 0x112;
const int BPL3DAT = 0x114;
const int BPL4DAT = 0x116;
const int BPL5DAT = 0x118;
const int BPL6DAT = 0x11A;
const int BPL7DAT = 0x11C;
const int BPL8DAT = 0x11E;
const int SPR0PTH = 0x120;
const int SPR0PTL = 0x122;
const int SPR1PTH = 0x124;
const int SPR1PTL = 0x126;
const int SPR2PTH = 0x128;
const int SPR2PTL = 0x12A;
const int SPR3PTH = 0x12C;
const int SPR3PTL = 0x12E;
const int SPR4PTH = 0x130;
const int SPR4PTL = 0x132;
const int SPR5PTH = 0x134;
const int SPR5PTL = 0x136;
const int SPR6PTH = 0x138;
const int SPR6PTL = 0x13A;
const int SPR7PTH = 0x13C;
const int SPR7PTL = 0x13E;
const int SPR0POS = 0x140;
const int SPR0CTL = 0x142;
const int SPR0DATA = 0x144;
const int SPR0DATB = 0x146;
const int SPR1POS = 0x148;
const int SPR1CTL = 0x14A;
const int SPR1DATA = 0x14C;
const int SPR1DATB = 0x14E;
const int SPR2POS = 0x150;
const int SPR2CTL = 0x152;
const int SPR2DATA = 0x154;
const int SPR2DATB = 0x156;
const int SPR3POS = 0x158;
const int SPR3CTL = 0x15A;
const int SPR3DATA = 0x15C;
const int SPR3DATB = 0x15E;
const int SPR4POS = 0x160;
const int SPR4CTL = 0x162;
const int SPR4DATA = 0x164;
const int SPR4DATB = 0x166;
const int SPR5POS = 0x168;
const int SPR5CTL = 0x16A;
const int SPR5DATA = 0x16C;
const int SPR5DATB = 0x16E;
const int SPR6POS = 0x170;
const int SPR6CTL = 0x172;
const int SPR6DATA = 0x174;
const int SPR6DATB = 0x176;
const int SPR7POS = 0x178;
const int SPR7CTL = 0x17A;
const int SPR7DATA = 0x17C;
const int SPR7DATB = 0x17E;
const int COLOR00 = 0x180;
const int COLOR01 = 0x182;
const int COLOR02 = 0x184;
const int COLOR03 = 0x186;
const int COLOR04 = 0x188;
const int COLOR05 = 0x18A;
const int COLOR06 = 0x18C;
const int COLOR07 = 0x18E;
const int COLOR08 = 0x190;
const int COLOR09 = 0x192;
const int COLOR10 = 0x194;
const int COLOR11 = 0x196;
const int COLOR12 = 0x198;
const int COLOR13 = 0x19A;
const int COLOR14 = 0x19C;
const int COLOR15 = 0x19E;
const int COLOR16 = 0x1A0;
const int COLOR17 = 0x1A2;
const int COLOR18 = 0x1A4;
const int COLOR19 = 0x1A6;
const int COLOR20 = 0x1A8;
const int COLOR21 = 0x1AA;
const int COLOR22 = 0x1AC;
const int COLOR23 = 0x1AE;
const int COLOR24 = 0x1B0;
const int COLOR25 = 0x1B2;
const int COLOR26 = 0x1B4;
const int COLOR27 = 0x1B6;
const int COLOR28 = 0x1B8;
const int COLOR29 = 0x1BA;
const int COLOR30 = 0x1BC;
const int COLOR31 = 0x1BE;
const int HTOTAL = 0x1C0;
const int HSSTOP = 0x1C2;
const int HBSTRT = 0x1C4;
const int HBSTOP = 0x1C6;
const int VTOTAL = 0x1C8;
const int VSSTOP = 0x1CA;
const int VBSTRT = 0x1CC;
const int VBSTOP = 0x1CE;
const int SPRHSTRT = 0x1D0;
const int SPRHSTOP = 0x1D2;
const int BPLHSTRT = 0x1D4;
const int BPLHSTOP = 0x1D6;
const int HHPOSW = 0x1D8;
const int HHPOSR = 0x1DA;
const int BEAMCON0 = 0x1DC;
const int HSSTRT = 0x1DE;
const int VSSTRT = 0x1E0;
const int HCENTER = 0x1E2;
const int DIWHIGH = 0x1E4;
const int FMODE = 0x1FC;
const int NOOP = 0x1FE;

// Register lists
const List<int> COPxLCL = [COP1LCL, COP2LCL];
const List<int> COPxLCH = [COP1LCH, COP2LCH];
const List<int> COPxJMP = [COPJMP1, COPJMP2];
const List<int> AUDxLCH = [AUD0LCH, AUD1LCH, AUD2LCH, AUD3LCH];
const List<int> AUDxLCL = [AUD0LCL, AUD1LCL, AUD2LCL, AUD3LCL];
const List<int> AUDxLEN = [AUD0LEN, AUD1LEN, AUD2LEN, AUD3LEN];
const List<int> AUDxPER = [AUD0PER, AUD1PER, AUD2PER, AUD3PER];
const List<int> AUDxVOL = [AUD0VOL, AUD1VOL, AUD2VOL, AUD3VOL];
const List<int> AUDxDAT = [AUD0DAT, AUD1DAT, AUD2DAT, AUD3DAT];
const List<int> BPLxPTH = [
  BPL1PTH,
  BPL2PTH,
  BPL3PTH,
  BPL4PTH,
  BPL5PTH,
  BPL6PTH,
  BPL7PTH,
  BPL8PTH,
];
const List<int> BPLxPTL = [
  BPL1PTL,
  BPL2PTL,
  BPL3PTL,
  BPL4PTL,
  BPL5PTL,
  BPL6PTL,
  BPL7PTL,
  BPL8PTL,
];
const List<int> BPLxDAT = [
  BPL1DAT,
  BPL2DAT,
  BPL3DAT,
  BPL4DAT,
  BPL5DAT,
  BPL6DAT,
  BPL7DAT,
  BPL8DAT,
];
const List<int> SPRxPTH = [
  SPR0PTH,
  SPR1PTH,
  SPR2PTH,
  SPR3PTH,
  SPR4PTH,
  SPR5PTH,
  SPR6PTH,
  SPR7PTH,
];
const List<int> SPRxPTL = [
  SPR0PTL,
  SPR1PTL,
  SPR2PTL,
  SPR3PTL,
  SPR4PTL,
  SPR5PTL,
  SPR6PTL,
  SPR7PTL,
];
const List<int> SPRxPOS = [
  SPR0POS,
  SPR1POS,
  SPR2POS,
  SPR3POS,
  SPR4POS,
  SPR5POS,
  SPR6POS,
  SPR7POS,
];
const List<int> SPRxCTL = [
  SPR0CTL,
  SPR1CTL,
  SPR2CTL,
  SPR3CTL,
  SPR4CTL,
  SPR5CTL,
  SPR6CTL,
  SPR7CTL,
];
const List<int> SPRxDATA = [
  SPR0DATA,
  SPR1DATA,
  SPR2DATA,
  SPR3DATA,
  SPR4DATA,
  SPR5DATA,
  SPR6DATA,
  SPR7DATA,
];
const List<int> SPRxDATB = [
  SPR0DATB,
  SPR1DATB,
  SPR2DATB,
  SPR3DATB,
  SPR4DATB,
  SPR5DATB,
  SPR6DATB,
  SPR7DATB,
];
const List<int> COLORx = [
  COLOR00,
  COLOR01,
  COLOR02,
  COLOR03,
  COLOR04,
  COLOR05,
  COLOR06,
  COLOR07,
  COLOR08,
  COLOR09,
  COLOR10,
  COLOR11,
  COLOR12,
  COLOR13,
  COLOR14,
  COLOR15,
  COLOR16,
  COLOR17,
  COLOR18,
  COLOR19,
  COLOR20,
  COLOR21,
  COLOR22,
  COLOR23,
  COLOR24,
  COLOR25,
  COLOR26,
  COLOR27,
  COLOR28,
  COLOR29,
  COLOR30,
  COLOR31,
];

// Pointer register pairs
const int BLTCPT = BLTCPTH;
const int BLTBPT = BLTBPTH;
const int BLTAPT = BLTAPTH;
const int BLTDPT = BLTDPTH;
const int COP1LC = COP1LCH;
const int COP2LC = COP2LCH;
const List<int> COPxLC = COPxLCH;
const int AUD0LC = AUD0LCH;
const int AUD1LC = AUD1LCH;
const int AUD2LC = AUD2LCH;
const int AUD3LC = AUD3LCH;
const List<int> AUDxLC = AUDxLCH;
const int BPL1PT = BPL1PTH;
const int BPL2PT = BPL2PTH;
const int BPL3PT = BPL3PTH;
const int BPL4PT = BPL4PTH;
const int BPL5PT = BPL5PTH;
const int BPL6PT = BPL6PTH;
const int BPL7PT = BPL7PTH;
const int BPL8PT = BPL8PTH;
const List<int> BPLxPT = BPLxPTH;
const int SPR0PT = SPR0PTH;
const int SPR1PT = SPR1PTH;
const int SPR2PT = SPR2PTH;
const int SPR3PT = SPR3PTH;
const int SPR4PT = SPR4PTH;
const int SPR5PT = SPR5PTH;
const int SPR6PT = SPR6PTH;
const int SPR7PT = SPR7PTH;
const List<int> SPRxPT = SPRxPTH;
