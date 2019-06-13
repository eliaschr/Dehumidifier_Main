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
			.bss	ADCCallbacks, 32 *2		;Callback functions for ADC channels
			.bss	ADCLastVals, 32 *2		;Buffer that contains the last converted values of
											; each analog input
			.bss	ADCBuffer, ADCBUFFSIZE*2;Buffer to hold the conversion results
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
			MOV		#00000h,&ADCBufStrt			;Clear the starting offset of the ADC Buffer
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
; ADCChannelCb
; Associates a callback function that will be called automatically when ADC has finished the
; conversion of the specified channel. The converted value entered to the callback function is
; stored in R4, so the callback function can handle it. The callback function is responsible
; for not altering any other register than R4 and return as soon as possiible due to the fact
; that it runs in Interrupt context.
; INPUT         : R10 contains the channel number
;                 R12 contains the address of the callback function
; OUTPUT        : None
; REGS USED     : R4, R10, R12
; REGS AFFECTED : R4
; STACK USAGE   : None
; VARS USED     : ADCCallbacks
; OTHER FUNCS   : None
ADCChannelCb:
			MOV		R10,R4					;Get a copy of the channel
			ADD		R4,R4					;Convert it to word offset
			MOV		R12,ADCCallbacks(R4)	;Add the callback in the list
			RET								;Return to caller


;----------------------------------------
; ADCReadBuffer
; Reads the first available value stored in the cyclic buffer
; INPUT         : None
; OUTPUT        : R4 contains the value read (if there is any).
;                 Carry Flag is set if there was no value available (empty buffer) or cleared
;                 if there is a new value in R4
; REGS USED     : R4
; REGS AFFECTED : R4
; STACK USAGE   : 2 = 1x Push
; VARS USED     : ADCBuffer, ADCBUFFSIZE, ADCBufLen, ADCBufStrt
; OTHER FUNCS   : None
ADCReadBuffer:
			CMP		#00000h,&ADCBufLen		;Is there a value available in cyclic buffer?
			JZ		ADCRB_NoVal				;No => then exit with carry flag set
			MOV		&ADCBufStrt,R4			;Get the offset of the first available value
			MOV		ADCBuffer(R4),R4		;Get this value in R4
			PUSH	SR						;Need to keep interrupts status
			DINT							;Disable interrupts - Critical section
			NOP
			INCD	&ADCBufStrt				;Advance the starting pointer to the next cell
			CMP		#ADCBUFFSIZE,&ADCBufStrt;Passed the end of it?
			JLO		ADCRB_SkipRvt			;No => do not revert to its beginning
			MOV		#00000h,&ADCBufStrt		;else, move the pointer to the beginning of the
											; cyclic buffer
ADCRB_SkipRvt:
			DECD	&ADCBufLen				;One word less in the buffer
			POP		SR						;Restore Interrupts status
			CLRC							;Clear carry to flag that there is a new value
ADCRB_NoVal:RET


;----------------------------------------
; Interrupt Service Routines
;========================================
;----------------------------------------
; ADCStoreVal
; The function adds the input value to the FIFO ADC cyclic buffer. The addition is always
; performed. The buffer keeps always the last (up to x, where x is its size in words) values.
; It doesnot overflow, it just forgets the previous values even if they were not read.
; eliaschr@NOTE: The function normally is called in ISR context. If it must be called outside
; of ISR context, the interrupts should be disabled!
; INPUT         : R4 contains the value to be added into cyclic buffer
; OUTPUT        : None
; REGS USED     : R15
; REGS AFFECTED : R15
; STACK USAGE   : None
; VARS USED     : ADCBuffer, ADCBUFFSIZE, ADCBufLen, ADCBufStrt
; OTHER FUNCS   : None
ADCStoreVal:
			MOV		&ADCBufStrt,R15			;Get the starting offset in cyclic buffer
			ADD		&ADCBufLen,R15			;Add the length of the stored data in buffer to
											; find the first "empty" cell
			CMP		#ADCBUFFSIZE,R15		;Passed the border of the buffer?
			JLO		ADCSV_SkipRvt			;No => then do not revert to its beginning
			SUB		#ADCBUFFSIZE,R15		;else, bring the pointer in buffer
ADCSV_SkipRvt:
			MOV		R4,ADCBuffer(R15)		;Store the value in buffer
			CMP		#ADCBUFFSIZE,&ADCBufLen	;Are all the cells of the buffer occupied?
			JHS		ADCSV_MStrt				;Yes => then have to move the starting pointer
			INCD	&ADCBufLen				;else, another word is added into the buffer
			RET
ADCSV_MStrt:
			INCD	&ADCBufStrt				;Forget the older word
			CMP		#ADCBUFFSIZE,&ADCBufStrt;Passed the end of the buffer?
			JLO		ADCSV_NoStrt			;No => Keep on
			MOV		#00000h,ADCBufStrt		;Revert to the beginning
ADCSV_NoStrt:
			RET


;----------------------------------------
; ADCGetChannelISR
; This is the real interrupt service routine that is triggered when ADC has finished the
; conversion of an analog channel
; INPUT         : None
; OUTPUT        : None
; REGS USED     : R4, R5, R15
; REGS AFFECTED : None
; STACK USAGE   : 8+ = 3x Push + 1x Call +Usage of callback function is there is one
; VARS USED     : ADCCallbacks, ADCLastIV, ADCLastVals
; OTHER FUNCS   : ADCStoreVal
ADCGetChannelISR:
			PUSH	R4
			PUSH	R5
			PUSH	R15
			MOV		&ADCLastIV,R5			;Get the last vector that triggered the interrupt
			SUB		#0000Ch,R5				;Since it is a channel ISR, sub the value of the
											; first (channel 0). Now R4 = word offset of the
											; triggered channel
			MOV		ADC12MEM0(R5),R4		;Get the converted value in R4
			MOV		ADC12MEMCTL0(R5),R15	;Get the current MCTLx value
			AND 	#ADC12INCH_31,R15		;Keep only the memory cell
			ADD		R15,R15					;Convert it to word offset
			MOV		R4,ADCLastVals(R15)		;Store the value read into last values buffer
			CALL	#ADCStoreVal			;Store the value into the cyclic buffer
			CMP		#00000h,ADCCallbacks(R5);Do we have to call a callback?
			JEQ		ADCGCI_SkipCb			;No => skip calling one
			CALL	ADCCallbacks(R5)		;else call the stored callback function to handle
											; the value
			JNC		ADCGCI_SkipCb			;Do we need to wake the system up?
			BIC		#LPM4,6(SP)				;Yes => then wake it up on exit
ADCGCI_SkipCb:
			POP		R15						;else, just leave
			POP		R5
			POP		R4
			RETI


;----------------------------------------
; ADCIDispatcher
; This is the Interrupt Service Routine called whenever there is an ADC event. It dispatches
; to the real ISR that will server the specific event.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : R4, R5, R15
; REGS AFFECTED : None
; STACK USAGE   : According to the ISR called
; VARS USED     : ADCLastIV
; OTHER FUNCS   : ADCGetChannelISR
ADCIDispatcher:
			MOV		&ADC12IV,&ADCLastIV		;Keep the last Interrupt Vector that triggered the
			ADD		&ADCLastIV,PC			; interrupt and jump to the associated function
			RETI							;00: No Interrupt
			RETI							;02: ADC Overflow (ADC12OVIFG)
			RETI							;04: ADC Timing Overflow (ADC12TOVIFG)
			RETI							;06: ADC High Window Level (ADC12HIIFG)
			RETI							;08: ADC Low Window Level (ADC12LOIFG)
			RETI							;0A: ADC In Window (ADC12INIFG)
			ADCGetChannelISR				;0C: ADC Channel 0 (ADC12IFG0)
			ADCGetChannelISR				;0E: ADC Channel 1 (ADC12IFG1)
			ADCGetChannelISR				;10: ADC Channel 2 (ADC12IFG2)
			ADCGetChannelISR				;12: ADC Channel 3 (ADC12IFG3)
			ADCGetChannelISR				;14: ADC Channel 4 (ADC12IFG4)
			ADCGetChannelISR				;16: ADC Channel 5 (ADC12IFG5)
			ADCGetChannelISR				;18: ADC Channel 6 (ADC12IFG6)
			ADCGetChannelISR				;1A: ADC Channel 7 (ADC12IFG7)
			ADCGetChannelISR				;1C: ADC Channel 8 (ADC12IFG8)
			ADCGetChannelISR				;1E: ADC Channel 9 (ADC12IFG9)
			ADCGetChannelISR				;20: ADC Channel 10 (ADC12IFG10)
			ADCGetChannelISR				;22: ADC Channel 11 (ADC12IFG11)
			ADCGetChannelISR				;24: ADC Channel 12 (ADC12IFG12)
			ADCGetChannelISR				;26: ADC Channel 13 (ADC12IFG13)
			ADCGetChannelISR				;28: ADC Channel 14 (ADC12IFG14)
			ADCGetChannelISR				;2A: ADC Channel 15 (ADC12IFG15)
			ADCGetChannelISR				;2C: ADC Channel 16 (ADC12IFG16)
			ADCGetChannelISR				;2E: ADC Channel 17 (ADC12IFG17)
			ADCGetChannelISR				;30: ADC Channel 18 (ADC12IFG18)
			ADCGetChannelISR				;32: ADC Channel 19 (ADC12IFG19)
			ADCGetChannelISR				;34: ADC Channel 20 (ADC12IFG20)
			ADCGetChannelISR				;36: ADC Channel 21 (ADC12IFG21)
			ADCGetChannelISR				;38: ADC Channel 22 (ADC12IFG22)
			ADCGetChannelISR				;3A: ADC Channel 23 (ADC12IFG23)
			ADCGetChannelISR				;3C: ADC Channel 24 (ADC12IFG24)
			ADCGetChannelISR				;3E: ADC Channel 25 (ADC12IFG25)
			ADCGetChannelISR				;40: ADC Channel 26 (ADC12IFG26)
			ADCGetChannelISR				;42: ADC Channel 27 (ADC12IFG27)
			ADCGetChannelISR				;44: ADC Channel 28 (ADC12IFG28)
			ADCGetChannelISR				;46: ADC Channel 29 (ADC12IFG29)
			ADCGetChannelISR				;48: ADC Channel 30 (ADC12IFG30)
			ADCGetChannelISR				;4A: ADC Channel 31 (ADC12IFG31)
			RETI							;4C: ADC Ready (ADC12RDYIFG)


;----------------------------------------
; Interrupt Vectors
;========================================
			.sect	ADC12_B_VECTOR			;Vector of ADC interrupt
			.short	ADCIDispatcher			;Interrupt Service Routine

