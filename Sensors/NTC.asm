;*********************************************************************************************
;* NTC Library                                                                               *
;*-------------------------------------------------------------------------------------------*
;* NTC.asm                                                                                   *
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
;* Library of procedures for making temperature measurements through a NTC.                  *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"NTC Library"
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
			.include "Resources/ADC.h43"	;Use the ADC library
			.include "NTC.h43"				;Local definitions
			.include "NTCAutoDefs.h43"		;Auto definitions according to settings in
											; NTC.h43


;----------------------------------------
; Definitions
;========================================


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------
			.bss	NTCStatus, 2			;Flags that describe the status of the NTC system
			.bss	NTCLastVal, 2			;Value fetched by the ADC
			.bss	NTCLastTemp, 2			;Temperature value converted


;----------------------------------------
; Constants
;========================================


;----------------------------------------
; Functions
;========================================
			.text
;Interrupt Service Routines must be global


;----------------------------------------
; NTCPInit
; Initializes the NTC I/O port pins
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : 4 = Call + Stack from called function
; VARS USED     : DEF_NTCMCTL, NTC_ACHANNEL, NTC_ENABLE, NTCA_PMASK, NTCA_SEL0, NTCA_SEL1,
;                 NTCP_DIR, NTCP_DOUT
; OTHER FUNCS   : ADCSetChannel
NTCPInit:	
			BIC.B	#NTC_ENABLE,&NTCP_DOUT			;Disable the NTC
			BIS.B	#NTC_ENABLE,&NTCP_DIR			;Enable pin is output
			BIS.B	#NTCA_PMASK,&NTCA_SEL0			;The input pin is an Analog Input to ADC
			BIS.B	#NTCA_PMASK,&NTCA_SEL1
			MOV		#NTC_ACHANNEL,R10				;Going to setup the NTC Analog Channel
			MOV		#DEF_NTCMCTL,R11				;The value to be used as MCTLx
			CALL	#ADCSetChannel					;Setup the channel
			MOV		#NTCCallback,R12				;Get the callback function to use
			CALL	#ADCChannelCb					;Set it as a callback
			RET
			

;----------------------------------------
; NTCTrigger
; Initializes the NTC I/O port pins
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : 2 = 1x Call
; VARS USED     : NTC_ACHANNEL, NTC_ENABLE, NTCP_DOUT
; OTHER FUNCS   : ADCStartSingle
NTCTrigger:
			BIS.B	#NTC_ENABLE,&NTCP_DOUT			;Enable the NTC divider
			MOV		#NTC_ACHANNEL,R10				;Channel to be sampled is the NTC one
			CALL	#ADCStartSingle					;Start sampling of NTC divider voltage
			RET


;----------------------------------------
; NTCReadTemp
; Converts the ADC value to temperature according to NTC_Table
; INPUT         : None
; OUTPUT        : R4 contains the associated temperature
; REGS USED     : R4, R12, R13, R14, R15
; REGS AFFECTED : R4, R12, R13, R14, R15
; STACK USAGE   : None
; VARS USED     : NTC_CONVERTED, NTC_Table, NTC_Table_END, NTCLastTemp, NTCLastVal, NTCStatus
; OTHER FUNCS   : None
NTCReadTemp:
			MOV		&NTCLastTemp,R4					;Get the possible converted value
			BIT		#NTC_CONVERTED,&NTCStatus		;Is the value already converted?
			JNZ		NTCRT_End						;Yes => Skip calculation
			MOV		&NTCLastVal,R4					;Get the value in question
			MOV		#(NTC_Table_END-NTC_Table),R15	;Maximum possible element (exclusive)
			MOV		#00000h,R13						;Minimum possible element (inclusive)
NTCRT_Loop:	MOV		R15,R14							;Get a copy of the maximum element
			SUB		R13,R14							;Subtract the first
			SHR		R14								;Divide by two to find the space between
			BIC		#00003h,R14						;Align to DWord because the table is
													; consisted of elements of two words each
			MOV		R13,R12							;Get the lower element
			ADD		R14,R12							;Add half of the space in DWords
			CMP		#00000h,R14						;Is the distance 0 DWords?
			JZ		NTCRT_Found						;Found the element
			CMP		NTC_Table(R12),R4				;Compare the ADC value of this element to
													; the one we search for
			JEQ		NTCRT_Found						;Do we have a match? => Found!
			JLO		NTCRT_SetHi						;Lower value? => Need to alter the hi val
			MOV		R12,R13							;Set the lower limit
			JMP		NTCRT_Loop						;Repeat the process until found
NTCRT_SetHi:
			MOV		R12,R15							;Set the higher limit
			JMP		NTCRT_Loop						;Repeat the process until found
NTCRT_Found:
			MOV		NTC_Table+2(R12),R4				;Get the associated temperature value
			BIS		#NTC_CONVERTED,&NTCStatus		;The last value is already converted
			MOV		R4,&NTCLastTemp					;Store the calculated value
NTCRT_End:	RET										;Return to caller


;----------------------------------------
; Interrupt Service Routines
;========================================
;----------------------------------------
; NTCCallback
; Not a real ISR, but it is called by the ADC ISR to inform that a new value is ready from NTC
; sensor. This, of course means that the used registers should stay unaffected. The ISR though
; uses R4 to keep the value fetched
; INPUT         : R4 contains the value read from the ADC
; OUTPUT        : Carry flag is set to signal the calling ISR the need to wake the system up
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : NTC_ENABLE, NTC_READY, NTCLastVal, NTCP_DOUT, NTCStatus
; OTHER FUNCS   : None
NTCCallback:
			BIC.B	#NTC_ENABLE,&NTCP_DOUT			;Disable the NTC subsystem
			CMP		R4,&NTCLastVal					;Is the new value equal to the last one?
			JZ		NTCCB_Skip						;Yes => No need to store it
			MOV		R4,&NTCLastVal					;Store the new value
			BIC		#NTC_CONVERTED,&NTCStatus		;Need to convert the new value
NTCCB_Skip:	BIS		#NTC_READY,&NTCStatus			;Flag that there is a new value stored
			SETC									;Flag the need to wake the system up, to
													; the calling ISR
			RET


;----------------------------------------
; Interrupt Vectors
;========================================

