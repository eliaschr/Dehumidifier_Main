;*********************************************************************************************
;* Relays Library                                                                            *
;*-------------------------------------------------------------------------------------------*
;* Relays.asm                                                                                *
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
;* Library to control the Relays/Actuators of the dehumidifier.                              *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"Relays Library"
			.width	94
			.tab	4

;*===========================================================================================*
;* Names And Values:                                                                         *
;* ------------------                                                                        *
;* RELAYS_MASK : The mask of all relay pins                                                  *
;*                                                                                           *
;*===========================================================================================*
;* Variables:                                                                                *
;* -----------                                                                               *
;*                                                                                           *
;*===========================================================================================*
;* Functions of the Library:                                                                 *
;* --------------------------                                                                *
;* RelayDelay  : Performs a blocking delay (without the use of a timer)                      *
;* RelaysPInit : Initializes the port pins for the relays as outputs                         *
;* RelPumpOn   : Powers on the compressor                                                    *
;* RelPumpOff  : Powers off the compressor                                                   *
;* RelFanOff   : Powers off the fan                                                          *
;* RelFanLow   : Sets the fan at low speed                                                   *
;* RelFanHigh  : Sets the fan at high speed                                                  *
;* RelAnionOn  : Powers on the anionizer                                                     *
;* RelAnionOff : Powers off the anionizer                                                    *
;* RelGetState : Gets the state of the relays                                                *
;*                                                                                           *
;*===========================================================================================*
;* Predefined Definitions Expected by the Library:                                           *
;* ------------------------------------------------                                          *
;*                                                                                           *
;*********************************************************************************************
			.cdecls	C,LIST,"msp430.h"		;Include device header file
			.include "Board.h43"			;Hardware Connections
			.include "Definitions.h43"		;Global definitions
			.include "Relays.h43"			;Local definitions
			.include "RelaysAutoDefs.h43"	;Auto definitions according to settings in
											; Relays.h43


;----------------------------------------
; Definitions
;========================================
;Lets create the mask of all relays
RELAYS_MASK:.equ	(RELPUMP|RELFANLO|RELFANHI|RELANION)


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
; RelayDelay
; Just waits :)
; The delay depends on the MClk frequency. The total delay performed is:
; R5 *((65536 *4) +4) + (R4 *4) +8 = R5 *(262144 +4) +(R4 *4) +8 =
; 262148*R5 + 4*R4 +8.
; INPUT         : R5:R4 pair contains the delay factor
; OUTPUT        : None
; REGS USED     : R4, R5
; REGS AFFECTED : R4, R5
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
RelayDelay:
			DEC		R4						;2
			JNZ		RelayDelay				;2
			DEC		R5						;2
			JC		RelayDelay				;2
			RET								;4


;----------------------------------------
; RelaysPInit
; Initializes the port pins that drive the Relays/Actuators.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : RELAYS_MASK, RELP_DIR, RELP_DOUT
; OTHER FUNCS   : None
RelaysPInit:
			BIC.B	#RELAYS_MASK,&RELP_DOUT	;No load is powered
			BIS.B	#RELAYS_MASK,&RELP_DIR	;All pins are outputs
			RET
			

;----------------------------------------
; RelPumpOn
; Enables the relay that powers up the compressor. Care should be taken, not to change the
; compressor state (On to Off and vise versa) at very short intervals
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : RELP_DOUT, RELPUMP
; OTHER FUNCS   : None
RelPumpOn:
			BIS.B	#RELPUMP,&RELP_DOUT		;Compressor goes on
			RET


;----------------------------------------
; RelPumpOff
; Disables the relay that powers up the compressor. Care should be taken, not to change the
; compressor state (On to Off and vise versa) at very short intervals
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : RELP_DOUT, RELPUMP
; OTHER FUNCS   : None
RelPumpOff:
			BIC.B	#RELPUMP,&RELP_DOUT		;Compressor goes off
			RET


;----------------------------------------
; RelFanOff
; Disables the relays that power up the fan
; INPUT         : None
; OUTPUT        : None
; REGS USED     : R4, R5
; REGS AFFECTED : R4, R5
; STACK USAGE   : 2 = Call
; VARS USED     : RELFANHI, RELFANLO, RELP_DOUT
; OTHER FUNCS   : RelayDelay
RelFanOff:
			BIC.B	#RELFANLO|RELFANHI,&RELP_DOUT;Fan goes off
			MOV		#0000Fh,R5				;Delay factor to wait until enabling low speed
			MOV		#0422Fh,R4				;(0.5 sec)
			CALL	#RelayDelay
			RET


;----------------------------------------
; RelFanLow
; Enables the relay that powers up the fan at low speed
; INPUT         : None
; OUTPUT        : None
; REGS USED     : R4, R5
; REGS AFFECTED : R4, R5
; STACK USAGE   : 2 = Call
; VARS USED     : RELFANHI, RELFANLO, RELP_DIN, RELP_DOUT
; OTHER FUNCS   : RelayDelay
RelFanLow:	BIT.B	#RELFANHI,&RELP_DIN		;Is the high speen of the fan on?
			JZ		RFL_SkipD				;No => then do it at once
			BIC.B	#RELFANHI,&RELP_DOUT	;Stop high speed of fan
			;A relay does not respond at once at its change, so we have to wait a little bit
			MOV		#0000Fh,R5				;Delay factor to wait until enabling low speed
			MOV		#0422Fh,R4				;(0.5 sec)
			CALL	#RelayDelay
RFL_SkipD:	BIS.B	#RELFANLO,&RELP_DOUT	;Enable Fan at low speed
			RET


;----------------------------------------
; RelFanHigh
; Enables the relay that powers up the fan at high speed
; INPUT         : None
; OUTPUT        : None
; REGS USED     : R4, R5
; REGS AFFECTED : R4, R5
; STACK USAGE   : 2 = Call
; VARS USED     : RELFANHI, RELFANLO, RELP_DIN, RELP_DOUT
; OTHER FUNCS   : RelayDelay
RelFanHigh:	BIT.B	#RELFANLO,&RELP_DIN	;Is the low speen of the fan on?
			JZ		RFH_SkipD				;No => then do it at once
			BIC.B	#RELFANLO,&RELP_DOUT	;Stop low speed of fan
			;A relay does not respond at once at its change, so we have to wait a little bit
			MOV		#0000Fh,R5				;Delay factor to wait until enabling low speed
			MOV		#0422Fh,R4				;(0.5 sec)
			CALL	#RelayDelay
RFH_SkipD:	BIS.B	#RELFANHI,&RELP_DOUT	;Enable Fan at high speed
			RET


;----------------------------------------
; RelAnionOn
; Enables the relay that powers up the anionizer. Care should be taken, not to change the
; anionizer state (On to Off and vise versa) at very short intervals
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : RELANION, RELP_DOUT
; OTHER FUNCS   : None
RelAnionOn:
			BIS.B	#RELANION,&RELP_DOUT	;Anionizer goes on
			RET


;----------------------------------------
; RelPumpOff
; Disables the relay that powers up the anionizer. Care should be taken, not to change the
; anionizer state (On to Off and vise versa) at very short intervals
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : RELANION, RELP_DOUT
; OTHER FUNCS   : None
RelAnionOff:
			BIC.B	#RELANION,&RELP_DOUT		;Anionizer goes off
			RET


;----------------------------------------
; RelGetState
; Returns the state of all the relays
; INPUT         : None
; OUTPUT        : R4 contains the  state of the relays
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : RELAYS_MASK, RELP_DIN
; OTHER FUNCS   : None
RelGetState:
			MOV.B	&RELP_DIN,R4				;Get the data from the port of the relays
			AND.B	#RELAYS_MASK,R4				;Keep only the relay bits
			RET


;----------------------------------------
; Interrupt Service Routines
;========================================


;----------------------------------------
; Interrupt Vectors
;========================================

