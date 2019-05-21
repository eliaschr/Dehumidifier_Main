;*********************************************************************************************
;*                                  Dehumidifier Project                                     *
;* ----------------------------------------------------------------------------------------- *
;*                                       Main Board                                          *
;*===========================================================================================*
;* main.asm                                                                                  *
;* Author: eliaschr                                                                          *
;* Copyright (c) 2019, Elias Chrysocheris                                                    *
;*                                                                                           *
;* This program is free software: you can redistribute it and/or modify                      *
;* it under the terms of the GNU General Public License as published by                      *
;* the Free Software Foundation, either version 3 of the License, or                         *
;* (at your option) any later version.                                                       *
;*                                                                                           *
;* This program is distributed in the hope that it will be useful,                           *
;* but WITHOUT ANY WARRANTY; without even the implied warranty of                            *
;* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                             *
;* GNU General Public License for more details.                                              *
;*                                                                                           *
;* You should have received a copy of the GNU General Public License                         *
;* along with this program.  If not, see <https://www.gnu.org/licenses/>.                    *
;*-------------------------------------------------------------------------------------------*
;* The main controller of the Dehumidifier. The System takes measurements of the environ-    *
;* mental parameters and controls the high power actuators enable the compressor, fan and    *
;* ionizer of a Juro Pro Oxygen16L Dehumidifier                                              *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"Main Functions and Entry Point"
			.width	94
			.tab	4

			.cdecls C,LIST,"msp430.h"			;Include device header file
			.include "Board.h43"				;Board connections
			.include "Definitions.h43"			;General definitions of the project
			.include "Keyboard/Keyboard.h43"	;Keyboard library
			.include "Leds/Leds.h43"			;Leds handling library


;*********************************************************************************************
; Global Definitions
;-------------------------------------------
			.def	StartMe						;Entry point should be global


;*********************************************************************************************
; Constants
;-------------------------------------------
			.sect ".const"


;*********************************************************************************************
; Functions
;----------------------------------------
			.text								;Assemble into program memory.
			.retain								;Overide ELF conditional linking and retain
												; current section.
			.retainrefs							;and retain any sections that have references
												; to current section.


;----------------------------------------
; InitAllPorts
; Initializes all the ports as outputs at logic 0. These settings will be changed by other
; initialization functions, that initialize the peripherals each hardware module uses. That
; way all the unused port pins stay outputs at low level without problem. After all the
; initialization process, LOCKLPM5 bit is cleared, so the final setup of the pins is activated
; INPUT         : None
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
InitAllPorts:
			MOV.B		#0FFh,R4
			MOV.B		#000h,&P1OUT		;Port 1 drives logic 0
			MOV.B		R4,&P1DIR			;Port 1 pins are all outputs

			MOV.B		#000h,&P2OUT		;Port 2 drives logic 0
			MOV.B		R4,&P2DIR			;Port 2 pins are all outputs

			MOV.B		#000h,&P3OUT		;Port 3 drives logic 0
			MOV.B		R4,&P3DIR			;Port 3 pins are all outputs

			MOV.B		#000h,&P4OUT		;Port 4 drives logic 0
			MOV.B		R4,&P4DIR			;Port 4 pins are all outputs

			MOV.B		#000h,&P5OUT		;Port 5 drives logic 0
			MOV.B		R4,&P5DIR			;Port 5 pins are all outputs

			MOV.B		#000h,&P6OUT		;Port 6 drives logic 0
			MOV.B		R4,&P6DIR			;Port 6 pins are all outputs

			MOV.B		#000h,&P7OUT		;Port 7 drives logic 0
			MOV.B		R4,&P7DIR			;Port 7 pins are all outputs

			MOV.B		#000h,&P8OUT		;Port 8 drives logic 0
			MOV.B		R4,&P8DIR			;Port 8 pins are all outputs

			MOV.B		#000h,&PAOUT		;Port A drives logic 0
			MOV.B		R4,&PADIR			;Port A pins are all outputs

			MOV.B		#000h,&PBOUT		;Port B drives logic 0
			MOV.B		R4,&PBDIR			;Port B pins are all outputs

			MOV.B		#000h,&PCOUT		;Port C drives logic 0
			MOV.B		R4,&PCDIR			;Port C pins are all outputs

			MOV.B		#000h,&PDOUT		;Port D drives logic 0
			MOV.B		R4,&PDDIR			;Port D pins are all outputs

			MOV.B		#000h,&PJOUT		;Port J drives logic 0
			MOV.B		R4,&PJDIR			;Port J pins are all outputs
			RET


;----------------------------------------
; InitSys
; Initializes the clock subsystem, RAM and local variables. Also, enables global interrupts
; INPUT         : None
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : R4
; STACK USAGE   : None
; VARS USED     : StckStrt
; OTHER FUNCS   : None
InitSys:
			BIS.B	#BIT4 | BIT5,&PJSEL0	;Pins PJ.4 and PJ.5 are used for LFXT 32KHz
			BIC.B	#LOCKLPM5,&PM5CTL0		;Release ports from Hi-Z

			;Must unlock the clock system in order to set it up
			MOV		#CSKEY,&CSCTL0			;Write the password in CSCTL0 to unlock CS Regs
			;To set the frequency of the DCO we must act as Errata CS12 describes
			MOV		#DIVA__4 | DIVS__4 | DIVM__4,&CSCTL3;Divide all clocks by 4
			MOV		#DCOFSEL_3 | DCORSEL,&CSCTL1	;DCO to 8MHz (DCORSEL=1, DCOFSEL=3)
			MOV		#0000Fh,R4				;2 Cycles - Delay factor for 60 cycles
DCODelay:	DEC		R4						;2 CyclesWait some cycles...
			JNZ		DCODelay				;2 Cycles
			MOV		#DIVA__1 | DIVS__1 | DIVM__1,&CSCTL3;No division of the clocks
			;Connect the clock sources to the propper Clock Signals
			MOV		#SELA__LFXTCLK | SELS__DCOCLK | SELM__DCOCLK,&CSCTL2
											;AClk = LFXT, SMClk = DCO and MClk = DCO
			BIC		#LFXTOFF,&CSCTL4		;Enable LFXT
			MOV		#00000h,&CSCTL0			;Lock the CS registers again

			;Lets see when the LFXT will be stable, to use it
			BIC		#LFXTOFFG,&CSCTL5		;Clear the Fault Flag of the LFXT
ReTestOsc:	BIC		#OFIFG,&SFRIFG1			;Clear the Oscillator Fault flag
			MOV		#0FFh,R4				;Small delay factor
OscDelay:	DEC		R4						;Wait some cycles...
			JNZ		OscDelay
			BIT.B	#OFIFG,&SFRIFG1			;Check if there is any problem in the oscillation
			JNZ		ReTestOsc				;Repeat testing until there is no fault

			;LFXT runs OK. Time to clear the RAM area (except stack)
			MOV		#01C00h,R4				;R4 points to the beginning of RAM area
ZapNextRAM:	CLR		0(R4)					;Clear the first word
			INCD	R4						;Point to the next word
			CMP		#StckStrt-00004h,R4		;Reached the end?
			JL		ZapNextRAM				;NO => Repeat zeroing of RAM word

			NOP
			EINT							;Enable Interrupts
			NOP
			RET								;Return to caller


;----------------------------------------
; StartMe
; This is the entry point of the program
StartMe:
			MOV.W	#StckStrt,SP				;Stack pointer at the top of RAM
StopWDT:	MOV.W	#WDTPW|WDTHOLD,&WDTCTL		;Stop watchdog timer

			CALL	#InitAllPorts				;Initialise all the port pins to a default
			CALL	#KBDPInit					;Initialize the ports used by the keyboard
			CALL	#LedsPInit					;Initialize the ports used by the leds
			CALL	#InitSys					;Initialize clock, RAM and variables, eint



;-------------------------------------------
; Stack Pointer definition
;===========================================
			.global	StckStrt
			.sect	.stack
StckStrt:


;-------------------------------------------
; Interrupt Vectors
;===========================================
			.sect	".reset"					;MSP430 RESET Vector
			.short	StartMe

