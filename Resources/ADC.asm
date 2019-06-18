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
			.include "Math.h43"				;Need some maths (Div32By16)
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
			.bss	ADCCalMult, 4			;ADC Calibration multiplier
			.bss	ADCCalDiff, 2			;ADC Calibration Divider (ADCAL85-ADCCAL30)
			.bss	ADCStatus, 2			;Status word for the ADC subsystem
			.bss	ADCLastTemp, 2			;Last converted temperature (ADC value)
			.bss	ADCLastCelcius, 2		;Last converted value to Celcius
			
;When debugging the ADC library, perhaps the following lines should be uncommented. They make
; the variables global in order for CCS Debugger to know the names and use them in watch
; windows, etc.
			.global	ADCCallbacks
			.global	ADCLastVals
			.global	ADCBuffer
			.global	ADCBufStrt
			.global	ADCBufLen
			.global	ADCLastIV
			.global	ADCCalMult
			.global	ADCCalDiff
			.global	ADCStatus
			.global	ADCLastTemp
			.global	ADCLastCelcius


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
; ADCSetRefV
; Configures the internal reference to produce a specific voltage and sets the ADC Calibration
; factors to help temperature calculation using the internal temperature sensor
; INPUT         : R10 contains the voltage to be set as defined by REFVSEL_x
; OUTPUT        : None
; REGS USED     : R4, R5, R6, R7, R10
; REGS AFFECTED : R4, R5, R6, R7
; STACK USAGE   : 2 = 1x Push
; VARS USED     : ADCCalDiff, ADCCalMult
; OTHER FUNCS   : None
ADCSetRefV:
			BIT		#REFGENBUSY,&REFCTL0		;Is the reference module busy?
			JNZ		ADCSetRefV					;Then wait, until it is free
			BIC		#REFVSEL_3,&REFCTL0			;Clear Reference Selection bits
			BIS		R10,&REFCTL0				;Set the needed reference voltage
			BIS		#REFON,&REFCTL0				;Enable the reference
			;Lets find the correct calibration values to use
			MOV		#01A1Ah,R4					;Assume calibration for 1.2V
			CMP		#00000h,R10					;Is it 1.2V?
			JZ		ADREF_Calc					;Yes => Calculate the values needed
			
			MOV		#01A1Eh,R4					;Assume calibration for 2.0V
			CMP		#REFVSEL_1,R10				;Is it 2.0V?
			JZ		ADREF_Calc					;Yes => Continue
			MOV		#01A22h,R4					;else, calibration is for 2.5V
ADREF_Calc:	;Calculate the necessary factors for the temperature equation
			MOV		@R4+,R5						;Get the calibration value at 30C (ADCCAL30)
			MOV		@R4,R4						;Get the calibration value at 85C (ADCCAL85)
			MOV		R4,R6						;Get a copy of ADCCAL85
			SUB		R5,R6						;R6 contains the difference of the factors
			MOV		R6,&ADCCalDiff				;This is the divider in the temperature
												; calculation formula
			PUSH	SR							;Going to use Multiplier, so keep GIE state
			DINT
			NOP
			MOV		R4,&MPY						;Going to multiply ADCCAL85...
			MOV		#300,&OP2					;... by 300
			NOP
			MOV		&RESLO,R6					;R7:R6 gets the result
			MOV		&RESHI,R7
			MOV		R5,&MPY						;Going to multiply ADCCAL30...
			MOV		#850,&OP2					;... by 850
			NOP
			SUB		&RESLO,R6					;R7:R6 = 300*ADCCAL85 - 850*ADCCAL30
			SUBC	&RESHI,R7
			POP		SR
			MOV		R6,&ADCCalMult				;Store the low word
			MOV		R7,&ADCCalMult +2			;Store the high word
			
ADREF_Wait:	BIT		#REFGENRDY,&REFCTL0			;Is the reference ready to be used?
			JZ		ADREF_Wait					;No => Wait until it is ready
			RET									;The internal reference is ready to be used


;----------------------------------------
; ADCEnableTempSensor
; Enables the internal voltage reference at its defautl voltage, configures a default
; ADC12MCTLx register to be used for the internal temperature sensor. The setup is based on
; the default values
; INPUT         : None
; OUTPUT        : None
; REGS USED     : R4, R5, R6, R7, R10, R11, R12
; REGS AFFECTED : R4, R5, R6, R7, R10, R11, R12
; STACK USAGE   : 2 = 1x Call + 1x Push in ADCSetRefV
; VARS USED     : ADCMCtlArr, DEF_ADCTEMPCHANNEL, DEF_ADCTEMPVREF, DEF_TEMPEOS
; OTHER FUNCS   : ADCChannelCb, ADCSetChannel, ADCSetRefV, ADCSetTempChannel, ADCTemperatureCb
ADCEnableTempSensor:
			MOV		#DEF_ADCTEMPVREF,R10
			CALL	#ADCSetRefV					;Setup internal VRef
			MOV		#DEF_ADCTEMPCHANNEL,R10
			MOV		#ADCTemperatureCb,R12		;The callback function of the temperatue
			CALL	#ADCChannelCb				; sensor channel is set
			;JMP	ADCSetTempChannel			;No need to have it here, as ADCSetTempChannel
												; function follows, but inserted for clarity


;----------------------------------------
; ADCSetTempChannel
; Configures a ADC12MCTLx register to be used for the internal temperature sensor
; INPUT         : R10 contains the channel number to configure
; OUTPUT        : None
; REGS USED     : R4, R10, R11
; REGS AFFECTED : R4, R11
; STACK USAGE   : 2 = 1x Push
; VARS USED     : ADCMCtlArr, DEF_TEMPEOS
; OTHER FUNCS   : ADCSetChannel
ADCSetTempChannel:	;Going to use internal reference of 2.5V for input A30. The EOS bit is set
					;according to DEF_TEMPEOS
			MOV		#DEF_TEMPEOS | ADC12VRSEL_1 | ADC12INCH_30,R11
			;JMP	ADCSetChannel				;No need to have it here because ADCSetChannel
												; function follows, but inserted for clarity

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
			PUSH	&ADC12CTL0					;Must keep the status of ENC bit
ADCSChWait:	BIT		#ADC12BUSY,&ADC12CTL1		;is the ADC Busy?
			JNZ		ADCSChWait					;Yes => wait...
			BIC		#ADC12ENC,&ADC12CTL0		;Ensure ENC=0
ADCSChSet:	MOV		R10,R4						;Get a copy of the channel number
			ADD		R4,R4						;Word offset
			MOV		ADCMCtlArr(R4),R4			;Get the target MCTLx register
			MOV		R11,0(R4)					;Store its value
			POP		&ADC12CTL0					;Restore ENC bit
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
			PUSH	&ADC12CTL0					;Must keep the status of ENC bit
ADCSWWait:	BIT		#ADC12BUSY,&ADC12CTL1		;is the ADC Busy?
			JNZ		ADCSWWait					;Yes => wait...
			BIC		#ADC12ENC,&ADC12CTL0		;Ensure ENC=0
ADCSWinSet:	MOV		R10,&ADC12LO				;Set the Low margin
			MOV		R11,&ADC12HI				;Set the High margin
			POP		&ADC12CTL0					;Restore ENC bit
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
			PUSH	&ADC12CTL0					;Must keep the status of ENC bit
ADCSTrWait:	BIT		#ADC12BUSY,&ADC12CTL1		;is the ADC Busy?
			JNZ		ADCSTrWait					;Yes => wait...
			BIC		#ADC12ENC,&ADC12CTL0		;Ensure ENC=0
			MOV		R10,R4						;Get a copy of the source number
			SWPB	R4							;Is like shofting the number 8 bits left
			RLAM	#2,R4						;Twice more to bring the number at SHSx
												; position
			BIC		#ADC12SHS_7,&ADC12CTL1		;Clear the source selection bits
			BIS		R4,&ADC12CTL1				;Set the new value
			POP		&ADC12CTL0					;Restore ENC bit
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
			BIT		#ADC12BUSY,&ADC12CTL1		;is the ADC Busy?
			JNZ		ADCStartSingle				;Yes => wait...
			BIC		#ADC12ENC,&ADC12CTL0		;Ensure ENC=0
			BIC		#ADC12CONSEQ_3,&ADC12CTL1	;Single Channel, Single Conversion mode
			BIC		#ADC12CSTARTADD_31,&ADC12CTL3;Clear the channel bits
			BIS		R10,&ADC12CTL3				;and set only the needed ones
ADCStrtIE:	MOV		#00000h,&ADC12IFGR0			;Clear all pending interrupts
			MOV		#00000h,&ADC12IFGR1
			MOV		#00000h,&ADC12IFGR2
			MOV		#0FFFFh,&ADC12IER0			;Enable interrupts for all input channels
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
			BIT		#ADC12BUSY,&ADC12CTL1		;is the ADC Busy?
			JNZ		ADCPrepareSingle			;Yes => wait...
			BIC		#ADC12ENC,&ADC12CTL0		;Ensure ENC=0
			BIC		#ADC12CONSEQ_3,&ADC12CTL1	;Single Channel, Single Conversion mode
			BIC		#ADC12CSTARTADD_31,&ADC12CTL3;Clear the channel bits
			BIS		R10,&ADC12CTL3				;and set only the needed ones
ADCPrepIE:	MOV		#00000h,&ADC12IFGR0			;Clear all pending interrupts
			MOV		#00000h,&ADC12IFGR1
			MOV		#00000h,&ADC12IFGR2
			MOV		#0FFFFh,&ADC12IER0			;Enable interrupts for all input channels
			MOV		#0FFFFh,&ADC12IER1
			MOV		#00000h,&ADC12IER2
												;Enable and start the conversion
			BIS		#ADC12ENC,&ADC12CTL0
			RET
			
			
;----------------------------------------
; ADCStartSequence
; Starts a conversion of sequence of channels, manually (using ADC12SC bit)
; INPUT         : R10 contains the starting channel (MCTLx) to be converted
; OUTPUT        : None
; REGS USED     : R10
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : ADCStrtIE
ADCStartSequence:
			BIT		#ADC12BUSY,&ADC12CTL1		;is the ADC Busy?
			JNZ		ADCStartSequence			;Yes => wait...
			BIC		#ADC12ENC,&ADC12CTL0		;Ensure ENC=0
			BIC		#ADC12CONSEQ_3,&ADC12CTL1	;Single Channel, Single Conversion mode
			BIS		#ADC12CONSEQ_1,&ADC12CTL1	;Set Sequence of channels
			BIC		#ADC12CSTARTADD_31,&ADC12CTL3;Clear the channel bits
			BIS		R10,&ADC12CTL3				;and set only the needed ones
			BIS		#ADC12MSC,&ADC12CTL0		;Multiple sample and conversion mode
			JMP		ADCStrtIE					;Enable interrupts and start scanning


;----------------------------------------
; ADCPrepareSequence
; Prepares the system to be ready for a conversion of sequence of channels. The triggering can
; be set either by ADC12SC bit later, or by another source, according to ADC12SHSx value
; INPUT         : R10 contains the channel (MCTLx) to be converted
; OUTPUT        : None
; REGS USED     : R10
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
ADCPrepareSequence:
			BIT		#ADC12BUSY,&ADC12CTL1		;is the ADC Busy?
			JNZ		ADCStartSequence			;Yes => wait...
			BIC		#ADC12ENC,&ADC12CTL0		;Ensure ENC=0
			BIS		#ADC12MSC,&ADC12CTL0		;Multiple sample and conversion mode
			BIC		#ADC12CONSEQ_3,&ADC12CTL1	;Single Channel, Single Conversion mode
			BIS		#ADC12CONSEQ_1,&ADC12CTL1	;Set Sequence of channels
			BIC		#ADC12CSTARTADD_31,&ADC12CTL3;Clear the channel bits
			BIS		R10,&ADC12CTL3				;and set only the needed ones
			JMP		ADCPrepIE					;Enable interrupts and start scanning


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
			BIS		#ADC12SC,&ADC12CTL0			;Trigger the ADC module manually
			RET


;----------------------------------------
; ADCGetTemperature
; Converts the last temperature reading to temperature. The return value is the temperature
; with one fractional digit, multiplied by 10. i.e. the temperature of 25,3 degrees Celcius is
; returned as 253
; INPUT         : None
; OUTPUT        : R4 contains the temperature in Celcius degrees (x10)
;                 Carry flag is cleared if there is a new reading, set if not
; REGS USED     : R4, R5, R6, R7, R15
; REGS AFFECTED : R4, R5, R6, R7
; STACK USAGE   : 6 = 1x Call + 4 by called function (Div32By16)
; VARS USED     : ADCCalDiff, ADCCalMult, ADCF_TEMPCONVOK, ADCF_TEMPOK, ADCLastCelcius,
;                 ADCStatus
; OTHER FUNCS   : Div32By16
ADCGetTemperature:
			BIT		#ADCF_TEMPOK,&ADCStatus		;Do we have a new value of temperature?
			SETC								;Assume no new value
			JZ		ADCGT_End
			BIT		#ADCF_TEMPCONVOK,&ADCStatus	;Is there a converted value already?
			JNZ		ADCGT_Good					;Yes => no need to convert it. Get the result
			PUSH	SR							;Need to disable temporarily the interrupts
			DINT								;Noone should disturb hardware multiplier
			NOP
			MOV		&ADCCalMult,&RESLO			;Prepare the "previous value" as ADCCalMult
			MOV		&ADCCalMult+2,&RESHI
			MOV		&ADCLastTemp,&MAC			;Going to Multiply ADC value to ...
			MOV		#550,&OP2					;... 550 and add it to ADCCalMult
			NOP
			MOV		&RESHI,R4					;... and divide it by...
			MOV		&RESLO,R5
			POP		SR							;(Restore interupts status)
			MOV		&ADCCalDiff,R6				;The calculated difference of the factors
			CALL	#Div32By16					;Perform the division
			;Now R4:R5 contain the result. Well only the 16 lower bits can have a value!
			MOV		R5,&ADCLastCelcius			;Store the new temperature value in Celcius
			BIS		#ADCF_TEMPCONVOK,&ADCStatus	;Flag that the copnversion is done
ADCGT_Good:	BIC		#ADCF_TEMPOK,&ADCStatus		;Last reading done
			MOV		&ADCLastCelcius,R4			;Get the last calculated Celcius value
			CLRC								;Clear carry flag to indicate a new value
ADCGT_End:	RET


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
			MOV		R10,R4						;Get a copy of the channel
			ADD		R4,R4						;Convert it to word offset
			MOV		R12,ADCCallbacks(R4)		;Add the callback in the list
			RET									;Return to caller


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
			CMP		#00000h,&ADCBufLen			;Is there a value available in cyclic buffer?
			JZ		ADCRB_NoVal					;No => then exit with carry flag set
			MOV		&ADCBufStrt,R4				;Get the offset of the first available value
			MOV		ADCBuffer(R4),R4			;Get this value in R4
			PUSH	SR							;Need to keep interrupts status
			DINT								;Disable interrupts - Critical section
			NOP
			INCD	&ADCBufStrt					;Advance the starting pointer to the next cell
			CMP		#ADCBUFFSIZE,&ADCBufStrt	;Passed the end of it?
			JLO		ADCRB_SkipRvt				;No => do not revert to its beginning
			MOV		#00000h,&ADCBufStrt			;else, move the pointer to the beginning of
												; the cyclic buffer
ADCRB_SkipRvt:
			DECD	&ADCBufLen					;One word less in the buffer
			POP		SR							;Restore Interrupts status
			CLRC								;Clear carry to flag that there is a new value
ADCRB_NoVal:
			RET


;----------------------------------------
; Interrupt Service Routines
;========================================
;----------------------------------------
; ADCTemperatureCb
; Not a real ISR, but it is called withing ISR context. This is the callback function of the
; internal temperature sensor reading.
; INPUT         : R4 contains the value read from the sensor
; OUTPUT        : Carry flag is set if there is a new value and the system needs to handle it
;                 or cleared if there is nothing new
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : ADCF_TEMPCONVOK, ADCF_TEMPOK, ADCLastTemp, ADCStatus
; OTHER FUNCS   : None
ADCTemperatureCb:
			CMP		R4,&ADCLastTemp				;Is this a new value?
			JEQ		ADCTCb_Out					;Nope => nothing to do
			MOV		R4,&ADCLastTemp				;OK, Store the new value
			BIS		#ADCF_TEMPOK,&ADCStatus		;Flag there is a new value fetched
			BIC		#ADCF_TEMPCONVOK,&ADCStatus	;Flag that this value has not been converted
												; to Celcius degrees
			SETC								;Set carry flag to signal the need to wake up
												; the system to handle the new value
ADCTCb_Out:
			RET


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
			MOV		&ADCBufStrt,R15				;Get the starting offset in cyclic buffer
			ADD		&ADCBufLen,R15				;Add the length of the stored data in buffer
												; to find the first "empty" cell
			CMP		#ADCBUFFSIZE,R15			;Passed the border of the buffer?
			JLO		ADCSV_SkipRvt				;No => then do not revert to its beginning
			SUB		#ADCBUFFSIZE,R15			;else, bring the pointer in buffer
ADCSV_SkipRvt:
			MOV		R4,ADCBuffer(R15)			;Store the value in buffer
			CMP		#ADCBUFFSIZE,&ADCBufLen		;Are all the cells of the buffer occupied?
			JHS		ADCSV_MStrt					;Yes => then have to move the starting pointer
			INCD	&ADCBufLen					;else, another word is added into the buffer
			RET
ADCSV_MStrt:
			INCD	&ADCBufStrt					;Forget the older word
			CMP		#ADCBUFFSIZE,&ADCBufStrt	;Passed the end of the buffer?
			JLO		ADCSV_NoStrt				;No => Keep on
			MOV		#00000h,ADCBufStrt			;Revert to the beginning
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
			MOV		&ADCLastIV,R5				;Get the last vector that triggered the int.
			SUB		#0000Ch,R5					;Since it is a channel ISR, sub the value of
												; the first (channel 0). Now R4 = word offset
												; of the triggered channel
			MOV		ADC12MEM0(R5),R4			;Get the converted value in R4
			MOV		ADC12MCTL0(R5),R15			;Get the current MCTLx value
			AND 	#ADC12INCH_31,R15			;Keep only the memory cell
			ADD		R15,R15						;Convert it to word offset
			MOV		R4,ADCLastVals(R15)			;Store the value read into last values buffer
			CALL	#ADCStoreVal				;Also, store the value into the cyclic buffer
			CMP		#00000h,ADCCallbacks(R5)	;Do we have to call a callback?
			JEQ		ADCGCI_SkipCb				;No => skip calling one
			CALL	ADCCallbacks(R5)			;else call the stored callback function to
												; handle the value
			JNC		ADCGCI_SkipCb				;Do we need to wake the system up?
			BIC		#LPM4,6(SP)					;Yes => then wake it up on exit
ADCGCI_SkipCb:
			POP		R15							;else, just leave
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
			MOV		&ADC12IV,&ADCLastIV			;Keep the last Interrupt Vector that triggered
			ADD		&ADCLastIV,PC				; the interrupt and jump to the associated ISR
			RETI								;00: No Interrupt
			RETI								;02: ADC Overflow (ADC12OVIFG)
			RETI								;04: ADC Timing Overflow (ADC12TOVIFG)
			RETI								;06: ADC High Window Level (ADC12HIIFG)
			RETI								;08: ADC Low Window Level (ADC12LOIFG)
			RETI								;0A: ADC In Window (ADC12INIFG)
			JMP		ADCGetChannelISR			;0C: ADC Channel 0 (ADC12IFG0)
			JMP		ADCGetChannelISR			;0E: ADC Channel 1 (ADC12IFG1)
			JMP		ADCGetChannelISR			;10: ADC Channel 2 (ADC12IFG2)
			JMP		ADCGetChannelISR			;12: ADC Channel 3 (ADC12IFG3)
			JMP		ADCGetChannelISR			;14: ADC Channel 4 (ADC12IFG4)
			JMP		ADCGetChannelISR			;16: ADC Channel 5 (ADC12IFG5)
			JMP		ADCGetChannelISR			;18: ADC Channel 6 (ADC12IFG6)
			JMP		ADCGetChannelISR			;1A: ADC Channel 7 (ADC12IFG7)
			JMP		ADCGetChannelISR			;1C: ADC Channel 8 (ADC12IFG8)
			JMP		ADCGetChannelISR			;1E: ADC Channel 9 (ADC12IFG9)
			JMP		ADCGetChannelISR			;20: ADC Channel 10 (ADC12IFG10)
			JMP		ADCGetChannelISR			;22: ADC Channel 11 (ADC12IFG11)
			JMP		ADCGetChannelISR			;24: ADC Channel 12 (ADC12IFG12)
			JMP		ADCGetChannelISR			;26: ADC Channel 13 (ADC12IFG13)
			JMP		ADCGetChannelISR			;28: ADC Channel 14 (ADC12IFG14)
			JMP		ADCGetChannelISR			;2A: ADC Channel 15 (ADC12IFG15)
			JMP		ADCGetChannelISR			;2C: ADC Channel 16 (ADC12IFG16)
			JMP		ADCGetChannelISR			;2E: ADC Channel 17 (ADC12IFG17)
			JMP		ADCGetChannelISR			;30: ADC Channel 18 (ADC12IFG18)
			JMP		ADCGetChannelISR			;32: ADC Channel 19 (ADC12IFG19)
			JMP		ADCGetChannelISR			;34: ADC Channel 20 (ADC12IFG20)
			JMP		ADCGetChannelISR			;36: ADC Channel 21 (ADC12IFG21)
			JMP		ADCGetChannelISR			;38: ADC Channel 22 (ADC12IFG22)
			JMP		ADCGetChannelISR			;3A: ADC Channel 23 (ADC12IFG23)
			JMP		ADCGetChannelISR			;3C: ADC Channel 24 (ADC12IFG24)
			JMP		ADCGetChannelISR			;3E: ADC Channel 25 (ADC12IFG25)
			JMP		ADCGetChannelISR			;40: ADC Channel 26 (ADC12IFG26)
			JMP		ADCGetChannelISR			;42: ADC Channel 27 (ADC12IFG27)
			JMP		ADCGetChannelISR			;44: ADC Channel 28 (ADC12IFG28)
			JMP		ADCGetChannelISR			;46: ADC Channel 29 (ADC12IFG29)
			JMP		ADCGetChannelISR			;48: ADC Channel 30 (ADC12IFG30)
			JMP		ADCGetChannelISR			;4A: ADC Channel 31 (ADC12IFG31)
			RETI								;4C: ADC Ready (ADC12RDYIFG)


;----------------------------------------
; Interrupt Vectors
;========================================
			.sect	ADC12_B_VECTOR				;Vector of ADC interrupt
			.short	ADCIDispatcher				;Interrupt Service Routine

