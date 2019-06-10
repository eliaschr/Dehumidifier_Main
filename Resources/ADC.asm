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
			MOV		#00000h,&ADCBuffStrt		;Clear the starting offset of the ADC Buffer
			MOV		#00000h,&ADCBufLen			;No data stored in it
			BIS		#ADC12ENC,&ADC12CTL0		;Enable conversions
			RET
			

;----------------------------------------
; ADCSetChannel
; Configures a ADC12MCTLx register
; INPUT         : R10 contains the channel number to configure
;                 R11 contains the value of the MCTLx register
; OUTPUT        : None
; REGS USED     : R4, R10, R11
; REGS AFFECTED : R4
; STACK USAGE   : None
; VARS USED     : ADCMCtlArr
; OTHER FUNCS   : None
ADCSetChannel:
			BIC		#ADC12ENC,&ADC12CTL0	;Ensure ENC=0
			MOV		R10,R4					;Get a copy of the channel number
			ADD		R4,R4					;Word offset
			MOV		ADCMCtlArr(R4),R4		;Get the target MCTLx register
			MOV		R11,0(R4)				;Store its value
			BIS		#ADC12ENC,&ADC12CTL0	;Enable conversion again
			RET


;----------------------------------------
; ADCSetWindow
; Configures the ADC12 Window High and Low registers
; INPUT         : R10 contains the Low margin of the window
;                 R11 contains the High margin of the window
; OUTPUT        : None
; REGS USED     : R10, R11
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
ADCSetWindow:
			BIC		#ADC12ENC,&ADC12CTL0	;Ensure ENC=0
			MOV		R10,&ADC12LO			;Set the Low margin
			MOV		R11,&ADC12HI			;Set the High margin
			BIS		#ADC12ENC,&ADC12CTL0	;Enable conversion again
			RET


;----------------------------------------
; Interrupt Service Routines
;========================================
ADCIDispatcher:
			ADD		&ADC12IV,PC
			RETI							;00: No Interrupt
			RETI							;02:
			RETI							;04:
			RETI							;06:
			RETI							;08:
			RETI							;0A:
			RETI							;0C:
			RETI							;0E:
			RETI							;10:
			RETI							;12:
			RETI							;14:
			RETI							;16:
			RETI							;18:
			RETI							;1A:
			RETI							;1C:
			RETI							;1E:
			RETI							;20:
			RETI							;22:
			RETI							;24:
			RETI							;26:
			RETI							;28:
			RETI							;2A:
			RETI							;2C:
			RETI							;2E:
			RETI							;30:
			RETI							;32:
			RETI							;34:
			RETI							;36:
			RETI							;38:
			RETI							;3A:
			RETI							;3C:
			RETI							;3E:
			RETI							;40:
			RETI							;42:
			RETI							;44:
			RETI							;46:
			RETI							;48:
			RETI							;4A:
			RETI							;4C:

;----------------------------------------
; Interrupt Vectors
;========================================
			.sect	ADC12_B_VECTOR			;Vector of ADC interrupt
			.short	ADCIDispatcher			;Interrupt Service Routine

