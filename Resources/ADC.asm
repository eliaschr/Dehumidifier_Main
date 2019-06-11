;*********************************************************************************************
;* ADC Library                                                                               *
;*-------------------------------------------------------------------------------------------*
;* ADC.asm                                                                                   *
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
;* Library of procedures for handling the internal ADC of MSP430.                            *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"Analog to Digital Converter Library"
			.width	94
			.tab	4

;*===========================================================================================*
;* Names And Values:                                                                         *
;* ------------------                                                                        *
;*                                                                                           *
;*===========================================================================================*
;* Variables:                                                                                *
;* -----------                                                                               *
;*                                                                                           *
;*===========================================================================================*
;* Functions of the Library:                                                                 *
;* --------------------------                                                                *
;*                                                                                           *
;*********************************************************************************************
			.cdecls	C,LIST,"msp430.h"		;Include device header file
			.include "Board.h43"			;Hardware Connections
			.include "Definitions.h43"		;Global definitions
			.include "ADC.h43"				;Local definitions
			.include "ADCAutoDefs.h43"		;Auto definitions according to settings in
											; ADC.h43


;----------------------------------------
; Definitions
;========================================


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------
			.bss	ADCBuffer, ADCBUFFLEN*2	;Buffer to hold the conversion results
			.bss	ADCBufStrt, 2			;Starting offset of the data in ADCBuffer
			.bss	ADCBufLen, 2			;Length of data stored in ADBuffer, in bytes
			.bss	ADCLastIV, 2			;The last interrupt vector that triggered ADC
											; interrupt


;----------------------------------------
; Constants
;========================================
			.sect ".const"

;Array to convert number of channel to MCTLx register
ADCMCtlArr:	.word	ADC12MCTL0, ADC12MCTL1, ADC12MCTL2, ADC12MCTL3
			.word	ADC12MCTL4, ADC12MCTL5, ADC12MCTL6, ADC12MCTL7
			.word	ADC12MCTL8, ADC12MCTL9, ADC12MCTL10, ADC12MCTL11
			.word	ADC12MCTL12, ADC12MCTL13, ADC12MCTL14, ADC12MCTL15
			.word	ADC12MCTL16, ADC12MCTL17, ADC12MCTL18, ADC12MCTL19
			.word	ADC12MCTL20, ADC12MCTL21, ADC12MCTL22, ADC12MCTL23
			.word	ADC12MCTL24, ADC12MCTL25, ADC12MCTL26, ADC12MCTL27
			.word	ADC12MCTL28, ADC12MCTL29, ADC12MCTL30, ADC12MCTL31


;----------------------------------------
; Functions
;========================================
			.text
;Interrupt Service Routines must be global
			.global	ADCIDispatcher

;----------------------------------------
; ADCInit
; Initializes the ADC subsystem
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : DEF_ADCDF, DEF_ADCRESOL, DEF_ADCSHT0, DEF_ADCSHT1
; OTHER FUNCS   : None
ADCInit:	BIC		#ADC12ENC,&ADC12CTL0		;Ensure ENC=0
			;Set the S/H timings and enable ADC module
			MOV		#DEF_ADCSHT1 | DEF_ADCSHT0 | ADC12ON,&ADC12CTL0
			MOV		#ADC12SHP,&ADC12CTL1		;Use the sampling timer, ADC12CLK from MODCLK,
												;Single channel, single conversion
			;Set the resolution and read back format of ADC conversion
			MOV		#DEF_ADCRESOL | DEF_ADCDF,&ADC12CTL2
			;Use the internal temperature and battery channels
			MOV		#ADC12TCMAP | ADC12BATMAP,&ADC12CTL3
			MOV		#00000h,&ADCBufStrt		;Clear the starting offset of the ADC Buffer
			MOV		#00000h,&ADCBufLen			;No data stored in it
;			BIS		#ADC12ENC,&ADC12CTL0		;Enable conversions
			RET
			

;----------------------------------------
; ADCSetChannel
; Configures a ADC12MCTLx register
; INPUT         : R10 contains the channel number to configure
;                 R11 contains the value of the MCTLx register
; OUTPUT        : None
; REGS USED     : R4, R10, R11
; REGS AFFECTED : R4
; STACK USAGE   : 2 = 1x Push
; VARS USED     : ADCMCtlArr
; OTHER FUNCS   : None
ADCSetChannel:
			PUSH	&ADC12CTL0				;Must keep the status of ENC bit
ADCSChWait:	BIT		#ADC12BUSY,&ADC12CTL1	;is the ADC Busy?
			JNZ		ADCSChWait				;Yes => wait...
			BIC		#ADC12ENC,&ADC12CTL0	;Ensure ENC=0
ADCSChSet:	MOV		R10,R4					;Get a copy of the channel number
			ADD		R4,R4					;Word offset
			MOV		ADCMCtlArr(R4),R4		;Get the target MCTLx register
			MOV		R11,0(R4)				;Store its value
			POP		&ADC12CTL0				;Restore ENC bit
			RET


;----------------------------------------
; ADCSetWindow
; Configures the ADC12 Window High and Low registers
; INPUT         : R10 contains the Low margin of the window
;                 R11 contains the High margin of the window
; OUTPUT        : None
; REGS USED     : R10, R11
; REGS AFFECTED : None
; STACK USAGE   : 2 = 1x Push
; VARS USED     : None
; OTHER FUNCS   : None
ADCSetWindow:
			PUSH	&ADC12CTL0				;Must keep the status of ENC bit
ADCSWWait:	BIT		#ADC12BUSY,&ADC12CTL1	;is the ADC Busy?
			JNZ		ADCSWWait				;Yes => wait...
			BIC		#ADC12ENC,&ADC12CTL0	;Ensure ENC=0
ADCSWinSet:	MOV		R10,&ADC12LO			;Set the Low margin
			MOV		R11,&ADC12HI			;Set the High margin
			POP		&ADC12CTL0				;Restore ENC bit
			RET
			
			
;----------------------------------------
; ADCSetTrigger
; Configures the ADC12 triggering source
; INPUT         : R10 contains the needed source as described in the datasheet (0 to 7)
; OUTPUT        : None
; REGS USED     : R4, R10
; REGS AFFECTED : R4
; STACK USAGE   : 2 = 1x Push
; VARS USED     : None
; OTHER FUNCS   : None
ADCSetTrigger:
			PUSH	&ADC12CTL0				;Must keep the status of ENC bit
ADCSTrWait:	BIT		#ADC12BUSY,&ADC12CTL1	;is the ADC Busy?
			JNZ		ADCSTrWait				;Yes => wait...
			BIC		#ADC12ENC,&ADC12CTL0	;Ensure ENC=0
			MOV		R10,R4					;Get a copy of the source number
			SWPB	R4						;Is like shofting the number 8 bits left
			RLAM	#2,R4					;Twice more to bring the number at SHSx position
			BIC		#ADC12SHS_7,&ADC12CTL1	;Clear the source selection bits
			BIS		R4,&ADC12CTL1			;Set the new value
			POP		&ADC12CTL0				;Restore ENC bit
			RET
			
			
;----------------------------------------
; ADCStartSingle
; Starts a single conversion - single channel, manually (using ADC12SC bit)
; INPUT         : R10 contains the channel (MCTLx) to be converted
; OUTPUT        : None
; REGS USED     : R10
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
ADCStartSingle:
			BIT		#ADC12BUSY,&ADC12CTL1	;is the ADC Busy?
			JNZ		ADCStartSingle			;Yes => wait...
			BIC		#ADC12ENC,&ADC12CTL0	;Ensure ENC=0
			BIC		#ADC12CONSEQ_3,&ADC12CTL1;Single Channel, Single Conversion mode
			BIC		#ADC12CSTARTADD_31,&ADC12CTL3;Clear the channel bits
			BIS		R10,&ADC12CTL3			;and set only the needed ones
			MOV		#00000h,&ADC12IFGR0		;Clear all pending interrupts
			MOV		#00000h,&ADC12IFGR1
			MOV		#00000h,&ADC12IFGR2
			MOV		#0FFFFh,&ADC12IER0		;Enable interrupts for all input channels
			MOV		#0FFFFh,&ADC12IER1
			MOV		#00000h,&ADC12IER2
											;Enable and start the conversion
			BIS		#ADC12ENC | ADC12SC,&ADC12CTL0
			RET


;----------------------------------------
; ADCPrepareSingle
; Prepares the system to be ready for a single conversion - single channel. The triggering can
; be set either by ADC12SC bit later, or by another source, according to ADC12SHSx value
; INPUT         : R10 contains the channel (MCTLx) to be converted
; OUTPUT        : None
; REGS USED     : R10
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
ADCPrepareSingle:
			BIT		#ADC12BUSY,&ADC12CTL1	;is the ADC Busy?
			JNZ		ADCPrepareSingle		;Yes => wait...
			BIC		#ADC12ENC,&ADC12CTL0	;Ensure ENC=0
			BIC		#ADC12CONSEQ_3,&ADC12CTL1;Single Channel, Single Conversion mode
			BIC		#ADC12CSTARTADD_31,&ADC12CTL3;Clear the channel bits
			BIS		R10,&ADC12CTL3			;and set only the needed ones
			MOV		#00000h,&ADC12IFGR0		;Clear all pending interrupts
			MOV		#00000h,&ADC12IFGR1
			MOV		#00000h,&ADC12IFGR2
			MOV		#0FFFFh,&ADC12IER0		;Enable interrupts for all input channels
			MOV		#0FFFFh,&ADC12IER1
			MOV		#00000h,&ADC12IER2
											;Enable and start the conversion
			BIS		#ADC12ENC,&ADC12CTL0
			RET


;----------------------------------------
; ADCTrigger
; Triggers manually the ADC module to start conversions. The conversion settings should be
; already prepared
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
ADCTrigger:
			BIS		#ADC12SC,&ADC12CTL0		;Trigger the ADC module manually
			RET


;----------------------------------------
; Interrupt Service Routines
;========================================
ADCIDispatcher:
			ADD		&ADC12IV,PC
			RETI							;00: No Interrupt
			RETI							;02: ADC Overflow (ADC12OVIFG)
			RETI							;04: ADC Timing Overflow (ADC12TOVIFG)
			RETI							;06: ADC High Window Level (ADC12HIIFG)
			RETI							;08: ADC Low Window Level (ADC12LOIFG)
			RETI							;0A: ADC In Window (ADC12INIFG)
			RETI							;0C: ADC Channel 0 (ADC12IFG0)
			RETI							;0E: ADC Channel 1 (ADC12IFG1)
			RETI							;10: ADC Channel 2 (ADC12IFG2)
			RETI							;12: ADC Channel 3 (ADC12IFG3)
			RETI							;14: ADC Channel 4 (ADC12IFG4)
			RETI							;16: ADC Channel 5 (ADC12IFG5)
			RETI							;18: ADC Channel 6 (ADC12IFG6)
			RETI							;1A: ADC Channel 7 (ADC12IFG7)
			RETI							;1C: ADC Channel 8 (ADC12IFG8)
			RETI							;1E: ADC Channel 9 (ADC12IFG9)
			RETI							;20: ADC Channel 10 (ADC12IFG10)
			RETI							;22: ADC Channel 11 (ADC12IFG11)
			RETI							;24: ADC Channel 12 (ADC12IFG12)
			RETI							;26: ADC Channel 13 (ADC12IFG13)
			RETI							;28: ADC Channel 14 (ADC12IFG14)
			RETI							;2A: ADC Channel 15 (ADC12IFG15)
			RETI							;2C: ADC Channel 16 (ADC12IFG16)
			RETI							;2E: ADC Channel 17 (ADC12IFG17)
			RETI							;30: ADC Channel 18 (ADC12IFG18)
			RETI							;32: ADC Channel 19 (ADC12IFG19)
			RETI							;34: ADC Channel 20 (ADC12IFG20)
			RETI							;36: ADC Channel 21 (ADC12IFG21)
			RETI							;38: ADC Channel 22 (ADC12IFG22)
			RETI							;3A: ADC Channel 23 (ADC12IFG23)
			RETI							;3C: ADC Channel 24 (ADC12IFG24)
			RETI							;3E: ADC Channel 25 (ADC12IFG25)
			RETI							;40: ADC Channel 26 (ADC12IFG26)
			RETI							;42: ADC Channel 27 (ADC12IFG27)
			RETI							;44: ADC Channel 28 (ADC12IFG28)
			RETI							;46: ADC Channel 29 (ADC12IFG29)
			RETI							;48: ADC Channel 30 (ADC12IFG30)
			RETI							;4A: ADC Channel 31 (ADC12IFG31)
			RETI							;4C: ADC Ready (ADC12RDYIFG)

;----------------------------------------
; Interrupt Vectors
;========================================
			.sect	ADC12_B_VECTOR			;Vector of ADC interrupt
			.short	ADCIDispatcher			;Interrupt Service Routine

