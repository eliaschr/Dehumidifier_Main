;*********************************************************************************************
;* HDC2080 Temperature/Humidity Sensor Library                                               *
;*-------------------------------------------------------------------------------------------*
;* HDC2080.asm                                                                               *
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
;* Library of procedures for connecting HDC2080 Temperature/Humidity sensor to the system    *
;* and control it through I2C bus, to make measurements.                                     *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"HDC2080 Temperature/Humidity Sensor Library"
			.width	94
			.tab	4

;*===========================================================================================*
;* Names And Values:                                                                         *
;* ------------------                                                                        *
;* The following definitions reflect the available registers of HDC2080.                     *
;* HDCR_TEMP        : Register for reading temperature reading                               *
;* HDCR_HUMID       : Register for reading humidity reading                                  *
;* HDCR_DRDY        : Register for reading DRDY/Interrupts status                            *
;* HDCR_MAXTEMP     : Register that holds the maximum temperature reading                    *
;* HDCR_MAXHUMID    : Register that holds the maximum humidity reading                       *
;* HDCR_INTCONF     : Register for configuring interrupts                                    *
;* HDCR_TOFFSET     : Register to control temperature offset                                 *
;* HDCR_HOFFSET     : Register to control humidity offset                                    *
;* HDCR_TLOWTHRESH  : Register to control the low temperature threshold                      *
;* HDCR_THIGHTHRESH : Register to control the high temperature threshold                     *
;* HDCR_HLOWTHRESH  : Register to control the low humidity threshold                         *
;* HDCR_HHIGHTHRESH : Register to control the high humidity threshold                        *
;* HDCR_CONFIG      : Configuration register                                                 *
;* HDCR_MEASCFG     : Register to configure measurements                                     *
;* HDCR_MANID       : Register to read Manufacturer ID (2 bytes)                             *
;* HDCR_DEVID       : Register to read Device ID (2 bytes)                                   *
;*                                                                                           *
;*===========================================================================================*
;* Variables:                                                                                *
;* -----------                                                                               *
;*                                                                                           *
;*===========================================================================================*
;* Functions of the Library:                                                                 *
;* --------------------------                                                                *
;* HDCInit          : Initializes the HDC2080 sensor to take automatic measurements at 1spm  *
;* HDCSendRaw       : Sends raw data to HDC2080                                              *
;* HDCReadRaw       : Reads raw data from HDC2080                                            *
;* HDCSetConfig     : Sets the configuration register                                        *
;* HDCSetMeasConfig : Sets the Measurement Configuration register                            *
;* HDCSetTHighTh    : Sets the Temperature High Threshold                                    *
;* HDCSetTLowTh     : Sets the Temperature Low Threshold                                     *
;* HDCSetTempOffs   : Sets the Temperature Offset of the reading                             *
;* HDCSetHHighTh    : Sets the Humnidity High Threshold                                      *
;* HDCSetHLowTh     : Sets the Humidity Low Threshold                                        *
;* HDCSetHumidOffs  : Sets the Humidity Offset                                               *
;* HDCSetIntConf    : Sets the Interrupt Control register                                    *
;* HDCSetRegister   : Sets a byte register                                                   *
;* HDCReadTH        : eads the value of both Temperature and Humidity readings               *
;* HDCReadT         : Reads the Temperature value                                            *
;* HDCReadH         : Reads the Humidity value                                               *
;* HDCReadDRDY      : Reads the DRDY/Interrupt Status register                               *
;* HDCReadMaxT      : Reads the Maximum Temperature recorded                                 *
;* HDCReadMaxH      : Reads the Maximum Humidity recorded                                    *
;* HDCReadMaxTH     : Reads both maximum recorded values for Temperature and Humidity        *
;* HDCReadTH        : Reads the Manufacturer and Device IDs                                  *
;*                                                                                           *
;*********************************************************************************************
			.cdecls	C,LIST,"msp430.h"		;Include device header file
			.include "Board.h43"			;Hardware Connections
			.include "Definitions.h43"		;Global definitions
			.include "Communications/I2CBus.h43" ;Include I2C support
			.include "HDC2080.h43"			;Local definitions
			.include "HDC2080AutoDefs.h43"	;Auto definitions according to settings in
											; HDC2080.h43


;----------------------------------------
; Definitions
;========================================
HDCR_TEMP:			.equ	00h					;Register for reading temperature reading
HDCR_HUMID:			.equ	02h					;Register for reading humidity reading
HDCR_DRDY:			.equ	04h					;Register for reading DRDY/Interrupts status
HDCR_MAXTEMP:		.equ	05h					;Register that holds the maximum temperature
												; reading
HDCR_MAXHUMID:		.equ	06h					;Register that holds the maximum humidity
												; reading
HDCR_INTCONF:		.equ	07h					;Register for configuring interrupts
HDCR_TOFFSET:		.equ	08h					;Register to control temperature offset
HDCR_HOFFSET:		.equ	09h					;Register to control humidity offset
HDCR_TLOWTHRESH:	.equ	0Ah					;Register to control the low temperature
												; threshold
HDCR_THIGHTHRESH:	.equ	0Bh					;Register to control the high temperature
												; threshold
HDCR_HLOWTHRESH:	.equ	0Ch					;Register to control the low humidity
												; threshold
HDCR_HHIGHTHRESH:	.equ	0Dh					;Register to control the high humidity
												; threshold
HDCR_CONFIG:		.equ	0Eh					;Configuration register
HDCR_MEASCFG:		.equ	0Fh					;Register to configure measurements
HDCR_MANID:			.equ	0FCh				;Register to read Manufacturer ID (2 bytes)
HDCR_DEVID:			.equ	0FEh				;Register to read Device ID (2 bytes)



;*********************************************************************************************
; Variables Definitions
;-------------------------------------------


;----------------------------------------
; Constants
;========================================


;----------------------------------------
; Functions
;========================================
			.text


;----------------------------------------
; HDCInit
; Initializes the HDC2080 sensor to take automatically 1 sample per minute
; INPUT         : None
; OUTPUT        : None
; REGS USED     :
; REGS AFFECTED :
; STACK USAGE   :
; VARS USED     : DEF_AMM, DEF_HDCHUMIDRES, DEF_HDCTEMPRES, DEF_MEASMODE, HDC_SOFT_RES
; OTHER FUNCS   : HDCSetConfig, HDCSetMeasConfig
HDCInit:	MOV.B	#HDC_SOFT_RES,R10			;Software Reset of sensor IC
			CALL	#HDCSetConfig
			MOV.B	#000h,R10					;Do not activate the automatic measurement yet
			CALL	#HDCSetConfig				; but exit reset mode
			;Set the mode register according to the default values
			MOV.B	#DEF_HDCTEMPRES | DEF_HDCHUMIDRES | DEF_MEASMODE,R10
			CALL	#HDCSetMeasConfig			;Set the register
			MOV.B	#DEF_AMM,R10				;Set the default measurement rate
			CALL	#HDCSetConfig
			RET


;----------------------------------------
; HDCSendRaw
; Sends raw data to HDC2080
; INPUT         : R10 contains the starting register address to be set
;                 R11 contains the number of bytes to be sent
;                 R12 points to the buffer that contains the data to be sent
; OUTPUT        : Carry Flag is set in case of an error
;                 R11 contains the number of bytes remain (0 if everything is OK)
;                 R12 points to the byte just after the one the error occured (Just passed the
;                     buffer of R11 bytes if everything went OK)
; REGS USED     : R4, R5, R10, R11, R12, R15
; REGS AFFECTED : R4, R5, R11, R12, R15
; STACK USAGE   : 4 = 2 for Call, +2 by each called function
; VARS USED     : HDCADDR
; OTHER FUNCS   : I2CSend, I2CStartTx, I2CStop
HDCSendRaw:	MOV		#HDCADDR,R4					;Address the HDC2080
			MOV		#00000h,R5					;Do not use the automatic counter
			CALL	#I2CStartTx					;Send Start condition and Slave address
			JC		HDCSREnd					;In case of an error exit
			MOV		R10,R4						;Send the Register Address
			CALL	#I2CSend
			JC		HDCSREnd					;In case of an error exit
			CMP		#00000h,R11					;Do we have more bytes to send?
			JZ		HDCSREnd					;No => then end the transmission
HDCSRLoop:	MOV.B	@R12+,R4					;Get one byte to be sent
			CALL	#I2CSend					;Send this byte
			JC		HDCSREnd					;In case of an error exit
			DEC		R11							;One byte less
			JNZ		HDCSRLoop					;Repeat if there are more
			CALL	#I2CStop					;Send a Stop condition
HDCSREnd:	RET


;----------------------------------------
; HDCSetConfig
; Sets the Configuration Register of HDC2080
; INPUT         : R10 contains the new configuration byte
; OUTPUT        : Carry Flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R11, R15
; STACK USAGE   : 4 = 2 for Call, +2 by each called function
; VARS USED     : HDCR_CONFIG
; OTHER FUNCS   : HDCSetRegister
HDCSetConfig:
			MOV		#HDCR_CONFIG,R11			;Address register to be used
			JMP		HDCSetRegister				;Set the register.


;----------------------------------------
; HDCSetMeasConfig
; Sets the Measurement Configuration Register of HDC2080
; INPUT         : R10 contains the new measurement configuration byte
; OUTPUT        : Carry Flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R11, R15
; STACK USAGE   : 4 = 2 for Call, +2 by each called function
; VARS USED     : HDCR_MEASCFG
; OTHER FUNCS   : HDCSetRegister
HDCSetMeasConfig:
			MOV		#HDCR_MEASCFG,R11			;Address register to be used
			JMP		HDCSetRegister				;Set the register.


;----------------------------------------
; HDCSetTHighTh
; Sets the Temperature High Threshold Register of HDC2080
; INPUT         : R10 contains the new threshold byte
; OUTPUT        : Carry Flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R11, R15
; STACK USAGE   : 4 = 2 for Call, +2 by each called function
; VARS USED     : HDCR_THIGHTHRESH
; OTHER FUNCS   : HDCSetRegister
HDCSetTHighTh:
			MOV		#HDCR_THIGHTHRESH,R11		;Address register to be used
			JMP		HDCSetRegister				;Set the register.


;----------------------------------------
; HDCSetTLowTh
; Sets the Temperature Low Threshold Register of HDC2080
; INPUT         : R10 contains the new threshold byte
; OUTPUT        : Carry Flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R11, R15
; STACK USAGE   : 4 = 2 for Call, +2 by each called function
; VARS USED     : HDCR_TLOWTHRESH
; OTHER FUNCS   : HDCSetRegister
HDCSetTLowTh:
			MOV		#HDCR_TLOWTHRESH,R11		;Address register to be used
			JMP		HDCSetRegister				;Set the register.


;----------------------------------------
; HDCSetTempOffs
; Sets the Temperature Offset Register of HDC2080
; INPUT         : R10 contains the new temperature offset byte
; OUTPUT        : Carry Flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R11, R15
; STACK USAGE   : 4 = 2 for Call, +2 by each called function
; VARS USED     : HDCR_TOFFSET
; OTHER FUNCS   : HDCSetRegister
HDCSetTempOffs:
			MOV		#HDCR_TOFFSET,R11			;Address register to be used
			JMP		HDCSetRegister				;Set the register.


;----------------------------------------
; HDCSetHHighTh
; Sets the Humidity High Threshold Register of HDC2080
; INPUT         : R10 contains the new threshold byte
; OUTPUT        : Carry Flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R11, R15
; STACK USAGE   : 4 = 2 for Call, +2 by each called function
; VARS USED     : HDCR_HHIGHTHRESH
; OTHER FUNCS   : HDCSetRegister
HDCSetHHighTh:
			MOV		#HDCR_HHIGHTHRESH,R11		;Address register to be used
			JMP		HDCSetRegister				;Set the register.


;----------------------------------------
; HDCSetHLowTh
; Sets the Humidity Low Threshold Register of HDC2080
; INPUT         : R10 contains the new threshold byte
; OUTPUT        : Carry Flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R11, R15
; STACK USAGE   : 4 = 2 for Call, +2 by each called function
; VARS USED     : HDCR_HLOWTHRESH
; OTHER FUNCS   : HDCSetRegister
HDCSetHLowTh:
			MOV		#HDCR_HLOWTHRESH,R11		;Address register to be used
			JMP		HDCSetRegister				;Set the register.


;----------------------------------------
; HDCSetHumidOffs
; Sets the Humidity Offset Register of HDC2080
; INPUT         : R10 contains the new humidity offset byte
; OUTPUT        : Carry Flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R11, R15
; STACK USAGE   : 4 = 2 for Call, +2 by each called function
; VARS USED     : HDCR_HOFFSET
; OTHER FUNCS   : HDCSetRegister
HDCSetHumidOffs:
			MOV		#HDCR_HOFFSET,R11			;Address register to be used
			JMP		HDCSetRegister				;Set the register.


;----------------------------------------
; HDCSetIntConf
; Sets the Interrupt Configuration Register of HDC2080
; INPUT         : R10 contains the new configuration byte
; OUTPUT        : Carry Flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R11, R15
; STACK USAGE   : 4 = 2 for Call, +2 by each called function
; VARS USED     : HDCADDR
; OTHER FUNCS   : HDCSetRegister
HDCSetIntConf:
			MOV		#HDCR_INTCONF,R11			;Address register to be used
			;JMP	HDCSetRegister				;Set the register. This line is commented out
												; since the HDCSetRegister function follows.
												; It appears here only for clarity

;----------------------------------------
; HDCSetBRegister
; Sets a one byte register of HDC2080
; INPUT         : R10 contains the new configuration byte
;                 R11 contains the register to be set
; OUTPUT        : Carry Flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R15
; STACK USAGE   : 4 = 2 for Call, +2 by each called function
; VARS USED     : HDCADDR
; OTHER FUNCS   : I2CSend, I2CStartTx, I2CStop
HDCSetRegister:
			MOV		#HDCADDR,R4					;Address the HDC2080
			MOV		#00000h,R5					;Do not use the automatic counter
			CALL	#I2CStartTx					;Send Start condition and Slave address
			JC		HDCSRegEnd					;In case of an error exit
			MOV.B	R11,R4						;Send the Register Address
			CALL	#I2CSend
			JC		HDCSRegEnd					;In case of an error exit
			MOV.B	R10,R4						;New value to set
			CALL	#I2CSend					;Send this byte
			JC		HDCSRegEnd					;In case of an error exit
			CALL	#I2CStop					;Send a Stop condition
HDCSRegEnd:	RET


;----------------------------------------
; HDCReadTH
; Reads the humidity reading of HDC2080
; INPUT         : None
; OUTPUT        : Carry flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R10, R11, R15
; STACK USAGE   : 4 = 2 by Call +2 by calling functions
; VARS USED     : HDCR_TEMP
; OTHER FUNCS   : HDCReadRaw
HDCReadTH:	MOV		#HDCR_TEMP,R10
			MOV		#00004h,R11
;			JMP		HDCReadRaw					;HDCReadRaw follows so no need to jump there
												;Appear only for clarity


;----------------------------------------
; HDCReadRaw
; Reads raw data from HDC2080
; INPUT         : R10 contains the starting register address to be read
;                 R11 contains the number of bytes to be read
; OUTPUT        : Carry flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R15
; STACK USAGE   : 4 = 2 by Call +2 by calling functions
; VARS USED     : HDCADDR
; OTHER FUNCS   : I2CSend, I2CStartRx, I2CStartTx, I2CStop
HDCReadRaw:	MOV		#HDCADDR,R4					;Address the HDC2080
			MOV		#00000h,R5					;Do not use the threshold counter
			CALL	#I2CStartTx					;Send a Start as a transmitter
			JC		HDCRREnd					;In case of an error exit
			MOV		R10,R4						;Register address to start reading from
			CALL	#I2CSend					;Send the address
			JC		HDCRREnd					;In case of an error exit
			MOV		#HDCADDR,R4					;Going to issue a Restart Condition
			MOV		R11,R5						; to receive R11 bytes
			CALL	#I2CStartRx					;Send the Restart condition and fetch R5 bytes
			;Normally the following lines would be uncommented, but since the byte coutner
			; interrupt is of low priority, it is never triggered while the bus is reading.
			; By using the automatic Stop generation, the I2C hardware subsystem sends the
			; Stop condition automatically and the following lines are not needed. They are
			; here only for clarity
;			JC		HDCRREnd					;In case of an error exit
;			CALL	#I2CStop					;Then Stop the transaction
HDCRREnd:	RET


;----------------------------------------
; HDCReadT
; Reads the temperature reading of HDC2080
; INPUT         : None
; OUTPUT        : Carry flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R10, R11, R15
; STACK USAGE   : 4 = 2 by Call +2 by calling functions
; VARS USED     : HDCR_TEMP
; OTHER FUNCS   : HDCReadRaw
HDCReadT:	MOV		#HDCR_TEMP,R10
			MOV		#00002h,R11
			JMP		HDCReadRaw


;----------------------------------------
; HDCReadH
; Reads the humidity reading of HDC2080
; INPUT         : None
; OUTPUT        : Carry flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R10, R11, R15
; STACK USAGE   : 4 = 2 by Call +2 by calling functions
; VARS USED     : HDCR_HUMID
; OTHER FUNCS   : HDCReadRaw
HDCReadH:	MOV		#HDCR_HUMID,R10
			MOV		#00002h,R11
			JMP		HDCReadRaw


;----------------------------------------
; HDCReadDRDY
; Reads the DRDY register reading of HDC2080
; INPUT         : None
; OUTPUT        : Carry flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R10, R11, R15
; STACK USAGE   : 4 = 2 by Call +2 by calling functions
; VARS USED     : HDCR_DRDY
; OTHER FUNCS   : HDCReadRaw
HDCReadDRDY:MOV		#HDCR_DRDY,R10
			MOV		#00001h,R11
			JMP		HDCReadRaw


;----------------------------------------
; HDCReadMaxT
; Reads the Maximum Temperature Reading register of HDC2080
; INPUT         : None
; OUTPUT        : Carry flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R10, R11, R15
; STACK USAGE   : 4 = 2 by Call +2 by calling functions
; VARS USED     : HDCR_MAXTEMP
; OTHER FUNCS   : HDCReadRaw
HDCReadMaxT:MOV		#HDCR_MAXTEMP,R10
			MOV		#00001h,R11
			JMP		HDCReadRaw


;----------------------------------------
; HDCReadMaxH
; Reads the Maximum Humidity Reading register of HDC2080
; INPUT         : None
; OUTPUT        : Carry flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R10, R11, R15
; STACK USAGE   : 4 = 2 by Call +2 by calling functions
; VARS USED     : HDCR_MAXHUMID
; OTHER FUNCS   : HDCReadRaw
HDCReadMaxH:MOV		#HDCR_MAXHUMID,R10
			MOV		#00001h,R11
			JMP		HDCReadRaw


;----------------------------------------
; HDCReadMaxTH
; Reads the Maximum Temperature and Humidity Reading registers of HDC2080
; INPUT         : None
; OUTPUT        : Carry flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R10, R11, R15
; STACK USAGE   : 4 = 2 by Call +2 by calling functions
; VARS USED     : HDCR_MAXTEMP
; OTHER FUNCS   : HDCReadRaw
HDCReadMaxTH:
			MOV		#HDCR_MAXTEMP,R10
			MOV		#00002h,R11
			JMP		HDCReadRaw


;----------------------------------------
; HDCReadID
; Reads the manufacturer and device IDs of HDC2080
; INPUT         : None
; OUTPUT        : Carry flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R10, R11, R15
; STACK USAGE   : 4 = 2 by Call +2 by calling functions
; VARS USED     : HDCR_MANID
; OTHER FUNCS   : HDCReadRaw
HDCReadID:	MOV		#HDCR_MANID,R10
			MOV		#00004h,R11
			JMP		HDCReadRaw

CPU40Errata:NOP


;----------------------------------------
; Interrupt Service Routines
;========================================


;----------------------------------------
; Interrupt Vectors
;========================================

