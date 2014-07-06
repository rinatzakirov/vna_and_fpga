/*-----------------------------------------------------------------------------
 * Hardware-dependent code for usb_jtag
 *-----------------------------------------------------------------------------
 * Copyright (C) 2007 Kolja Waschk, ixo.de
 *-----------------------------------------------------------------------------
 * This code is part of usbjtag. usbjtag is free software; you can redistribute
 * it and/or modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the License,
 * or (__at your option) any later version. usbjtag is distributed in the hope
 * that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.  You should have received a
 * copy of the GNU General Public License along with this program in the file
 * COPYING; if not, write to the Free Software Foundation, Inc., 51 Franklin
 * St, Fifth Floor, Boston, MA  02110-1301  USA
 *-----------------------------------------------------------------------------
 */

#include <fx2regs.h>
#include "hardware.h"
#include "delay.h"

// comment in (define!) if you want outputs disabled when possible
#define HAVE_OENABLE 1

//-----------------------------------------------------------------------------

/* JTAG TCK, AS/PS DCLK */

__sbit __at 0xB5          TCK; /* Port D.5 */
#define bmTCKOE       bmBIT5
#define SetTCK(x)     do{TCK=(x);}while(0)

/* JTAG TDI, AS ASDI, PS DATA0 */

__sbit __at 0xB4          TDI; /* Port D.4 */
#define bmTDIOE       bmBIT4
#define SetTDI(x)     do{TDI=(x);}while(0)

/* JTAG TMS, AS/PS nCONFIG */

__sbit __at 0xB7          TMS; /* Port D.7 */
#define bmTMSOE       bmBIT7
#define SetTMS(x)     do{TMS=(x);}while(0)

/* JTAG TDO, AS/PS CONF_DONE */

__sbit __at 0xB6          TDO; /* Port D.6 */
#define bmTDOOE       bmBIT6
#define GetTDO(x)     TDO

#define GetASDO() 1

//-----------------------------------------------------------------------------

#define bmPROGOUTOE (bmTCKOE|bmTDIOE|bmTMSOE)
#define bmPROGINOE  (bmTDOOE)

//-----------------------------------------------------------------------------

void ProgIO_Poll(void)    {}
// These aren't called anywhere in usbjtag.c, but I plan to do so...
void ProgIO_Enable(void)  {}
void ProgIO_Disable(void) {}
void ProgIO_Deinit(void)  {}

void ProgIO_Init(void)
{
  /* The following code depends on your actual circuit design.
     Make required changes _before_ you try the code! */

  // set the CPU clock to 48MHz, enable clock output to FPGA
  CPUCS = bmCLKOE | bmCLKSPD1;

  // Use internal 48 MHz, enable output, use "Port" mode for all pins
  IFCONFIG = bmIFCLKSRC | bm3048MHZ | bmIFCLKOE;

  mdelay(500); // wait for supply to come up
/*
#ifdef HAVE_OENABLE
  OED=(OED&~(bmPROGINOE | bmPROGOUTOE)); // Output disable
#else
  OED=(OED&~bmPROGINOE) | bmPROGOUTOE; // Output enable
#endif
*/
  OED = bmPROGOUTOE;// Output enable
}

void ProgIO_Set_State(unsigned char d)
{
  /* Set state of output pins:
   *
   * d.0 => TCK
   * d.1 => TMS
   * d.2 => nCE (only #ifdef HAVE_AS_MODE)
   * d.3 => nCS (only #ifdef HAVE_AS_MODE)
   * d.4 => TDI
   * d.5 => LED / Output Enable
   */

#ifdef HAVE_OENABLE
  //if((d & bmBIT5) == 0)
  //  OED=bmPROGOUTOE;//OED=(OED&~(bmPROGINOE | bmPROGOUTOE)); // Output disable
#endif

  SetTCK((d & bmBIT0) ? 1 : 0);
  SetTMS((d & bmBIT1) ? 1 : 0);
  SetTDI((d & bmBIT4) ? 1 : 0);

#ifdef HAVE_OENABLE
  //if((d & bmBIT5) != 0)
  //  OED = bmPROGOUTOE;//OED=(OED&~bmPROGINOE) | bmPROGOUTOE; // Output enable
#endif
}

unsigned char ProgIO_Set_Get_State(unsigned char d)
{
  /* Set state of output pins (s.a.)
   * then read state of input pins:
   *
   * TDO => d.0
   * DATAOUT => d.1 (only #ifdef HAVE_AS_MODE)
   */

  ProgIO_Set_State(d);
  return (GetASDO()<<1)|GetTDO();
}

//-----------------------------------------------------------------------------

void ProgIO_ShiftOut(unsigned char c)
{
  /* Shift out byte C: 
   *
   * 8x {
   *   Output least significant bit on TDI
   *   Raise TCK
   *   Shift c right
   *   Lower TCK
   * }
   */
 
  (void)c; /* argument passed in DPL */

  __asm
        MOV  A,DPL
        ;; Bit0
        RRC  A
        MOV  _TDI,C
        SETB _TCK
        ;; Bit1
        RRC  A
        CLR  _TCK
        MOV  _TDI,C
        SETB _TCK
        ;; Bit2
        RRC  A
        CLR  _TCK
        MOV  _TDI,C
        SETB _TCK
        ;; Bit3
        RRC  A
        CLR  _TCK
        MOV  _TDI,C
        SETB _TCK
        ;; Bit4
        RRC  A
        CLR  _TCK
        MOV  _TDI,C
        SETB _TCK
        ;; Bit5
        RRC  A
        CLR  _TCK
        MOV  _TDI,C
        SETB _TCK
        ;; Bit6
        RRC  A
        CLR  _TCK
        MOV  _TDI,C
        SETB _TCK
        ;; Bit7
        RRC  A
        CLR  _TCK
        MOV  _TDI,C
        SETB _TCK
        NOP 
        CLR  _TCK
        ret
  __endasm;
}

unsigned char ProgIO_ShiftInOut(unsigned char c)
{
  /* Shift out byte C, shift in from TDO:
   *
   * 8x {
   *   Read carry from TDO
   *   Output least significant bit on TDI
   *   Raise TCK
   *   Shift c right, append carry (TDO) __at left
   *   Lower TCK
   * }
   * Return c.
   */

   (void)c; /* argument passed in DPL */

  __asm
        MOV  A,DPL

        ;; Bit0
        MOV  C,_TDO
        RRC  A
        MOV  _TDI,C
        SETB _TCK
        CLR  _TCK
        ;; Bit1
        MOV  C,_TDO
        RRC  A
        MOV  _TDI,C
        SETB _TCK
        CLR  _TCK
        ;; Bit2
        MOV  C,_TDO
        RRC  A
        MOV  _TDI,C
        SETB _TCK
        CLR  _TCK
        ;; Bit3
        MOV  C,_TDO
        RRC  A
        MOV  _TDI,C
        SETB _TCK
        CLR  _TCK
        ;; Bit4
        MOV  C,_TDO
        RRC  A
        MOV  _TDI,C
        SETB _TCK
        CLR  _TCK
        ;; Bit5
        MOV  C,_TDO
        RRC  A
        MOV  _TDI,C
        SETB _TCK
        CLR  _TCK
        ;; Bit6
        MOV  C,_TDO
        RRC  A
        MOV  _TDI,C
        SETB _TCK
        CLR  _TCK
        ;; Bit7
        MOV  C,_TDO
        RRC  A
        MOV  _TDI,C
        SETB _TCK
        CLR  _TCK

        MOV  DPL,A
        ret
  __endasm;

  /* return value in DPL */

  return c;
}


