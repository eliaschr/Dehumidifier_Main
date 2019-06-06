;*********************************************************************************************
;* I2C Bus Support Library                                                                   *
;*-------------------------------------------------------------------------------------------*
;* I2CBus.asm                                                                                *
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
;* Library that creates the infastructure to use the I2C bus of the microcontroller. It can  *
;* be used to communicate to EEPROMs, Sensorc e.t.c.                                         *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"I2C Bus Support Library"
			.width	94
			.tab	4

;*===========================================================================================*
;* Names And Values:                                                                         *
;* ------------------                                                                        *
;* I2CP_MASK   : Mask bit for the pins used as I2C bus                                       *
;* Variable I2CStatus is consisted of bit flags that represent various states. The following *
;* definitions describe the bits and their meanings:                                         *
;* I2CBUZY     : I2C Bus is buzy (Transaction in progress). The bit is set when there is a   *
;*               Start Condition and reset when there is a Stop one                          *
;* I2CTRANSMIT : I2C Subsystem acts as Transmitter (Write data to device)                    *
;* I2CPRESTOP  : I2C Early Stop condition met => Scheduled bytes were skipped                *
;* I2CNACKRECV : I2C Received a NAck                                                         *
;* I2CCOUNTOK  : Threashold counter reached                                                  *
;* I2CRXOVFL   : Rx buffer overflow. Data were lost                                          *
;* I2CRXFULL   : Rx Buffer is now full. No more bytes to store                               *
;* I2CRXLIMIT  : When the Rx buffer has reached a threshold, this flag is set to notify for  *
;*               Almost Full condition. The threshold is set by I2CRXTHRESHOLD.              *
;* I2CTXINUSE  : Flags that the transmitter is in use now                                    *
;* I2CRXINUSE  : Flags that the receiver expects more data (in use)                          *
;* The transmission buffer contains words of data in order to keep not only the bytes to be  *
;* sent, but also the slave addresses for Start Conditions, or Restart Conditions or Stop    *
;* ones. The following flag defines if the word is a condition and if the master acts as a   *
;* transmitter or receiver.                                                                  *
;* I2CB_UCTR                                                                                 *
;*                                                                                           *
;*===========================================================================================*
;* Variables:                                                                                *
;* -----------                                                                               *
;* I2CTxBuff : I2C Transmission buffer (contains words)                                      *
;* I2CRxBuff : I2C Transmission buffer                                                       *
;* I2CTxStrt : Starting offset of transmission buffer                                        *
;* I2CTxLen  : Length of data in transmission buffer                                         *
;* I2CRxStrt : Starting offset of reception buffer                                           *
;* I2CRxLen  : Length of data written in reception buffer                                    *
;* I2CStatus : Some status flags                                                             *
;*                                                                                           *
;*===========================================================================================*
;* Functions of the Library:                                                                 *
;* --------------------------                                                                *
;*                                                                                           *
;*===========================================================================================*
;* Predefined Definitions Expected by the Library:                                           *
;* ------------------------------------------------                                          *
;* I2C_SCL      : I2C Clock line pin                                                         *
;* I2C_SDA      : I2C Data line pin                                                          *
;* I2CTXBUFFLEN : Size of the Tx Circular Buffer in words                                    *
;* I2CRXBUFFLEN : Size of the Rx Circular Buffer in bytes                                    *
;*                                                                                           *
;*********************************************************************************************
			.cdecls	C,LIST,"msp430.h"		;Include device header file
			.include "Board.h43"			;Hardware Connections
			.include "Definitions.h43"		;Global definitions
			.include "I2CBus.h43"			;Local definitions
			.include "I2CAutoDefs.h43"		;Auto definitions according to settings in
											; I2CBus.h43


;----------------------------------------
; Definitions
;========================================
;Flag in TxBuffer word that presents UCRX of the following Start Condition
I2CB_UCTR:	.equ	BITF					;UCTR Flag for the following Start Condition

;Mask of all bits used by I2C pins
I2CP_MASK:	.equ	(I2C_SCL | I2C_SDA)


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------
			.bss	I2CTxBuff, I2CTXBUFFLEN *2	;I2C Transmission buffer (contains words)
			.bss	I2CRxBuff, I2CRXBUFFLEN	;I2C Transmission buffer
			.bss	I2CTxStrt, 2			;Starting offset of transmission buffer
			.bss	I2CTxLen, 2				;Length of data in transmission buffer
			.bss	I2CRxStrt, 2			;Starting offset of reception buffer
			.bss	I2CRxLen, 2				;Length of data written in reception buffer
			.bss	I2CStatus, 2			;Some status flags

;When debugging the subsystem, the variables should be global in order for CCS to address them
; When debugging uncomment the following lines
			.global	I2CTxBuff
			.global	I2CRxBuff
			.global	I2CTxStrt
			.global	I2CTxLen
			.global	I2CRxStrt
			.global	I2CRxLen
			.global	I2CStatus


;----------------------------------------
; Constants
;========================================


;----------------------------------------
; Functions
;========================================
			.text
			.global	I2CDispatcher			;ISRs should be global


;----------------------------------------
; I2CPInit
; Initialize the associated eUSCI pins to be used as I2C
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : I2C_SEL0VAL, I2C_SEL1VAL, I2CP_MASK, I2CP_SEL0, I2CP_SEL1
; OTHER FUNCS   : None
I2CPInit:	BIC.B	#I2CP_MASK,&I2CP_SEL0	;Clear the selection bits used byt this I2C
			BIC.B	#I2CP_MASK,&I2CP_SEL1	; in both Special Function Selection registers
			BIS.B	#I2C_SEL0VAL,&I2CP_SEL0	;Now set them as supposed to use them as I2C
			BIS.B	#I2C_SEL1VAL,&I2CP_SEL1
			RET


;----------------------------------------
; I2CInit
; Initialize the I2C bus to be used for Humidity and Temperature sensor
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : I2C_BPSDIV, I2CBUZY, I2CRXINUSE, I2CStatus, I2CTRANSMIT, I2CTXINUSE,
;                 I2CU_BRW, I2CU_CTLW0, I2CU_CTLW1
; OTHER FUNCS   : None
I2CInit:	BIS		#UCSWRST,&I2CU_CTLW0	;Keep associated module in reset to configure it
			BIC		#I2CBUZY | I2CTXINUSE | I2CRXINUSE | I2CTRANSMIT,&I2CStatus	;Bus is free
			BIS		#UCMODE_3 | UCMST | UCSYNC,&I2CU_CTLW0
											;Set I2C master mode, in sync
			BIC		#UCASTP_3,&I2CU_CTLW1	;Clear both bits of STOP generation mode (No auto-
											; matic STOP condition)
			BIS		#UCASTP_2,&I2CU_CTLW1	;Automatic Stop when threshold is reached
			MOV		#I2C_BPSDIV,&I2CU_BRW	;Set divider for the correct bit rate
			BIC		#UCSWRST,&I2CU_CTLW0	;Stop reset mode. I2C is ready to be used
			RET
			

;----------------------------------------
; I2CStartTx
; Produces a Start condition on I2C bus and sends the Address byte. After that, it is ready to
; transmit more bytes
; INPUT         : R4 contains the Slave to be addressed
;                 R5 contains the number of bytes to be sent, or 0 to check it manually. After
;                 that number of bytes the transmitter will NOT send a Stop condition, as the
;                 main threads may need to send a Restart one
; OUTPUT        : If everything is fine, the carry flag is cleared. If the consition is not
;                 sent and it is not scheduled the Carry Flag is set to indicate the error
; REGS USED     : R4, R5, R15
; REGS AFFECTED : R4, R15
; STACK USAGE   : 2
; VARS USED     : I2CB_UCTX, I2CBUZY, I2CRXINUSE, I2CStatus, I2CTxBuff, I2CTxStrt, I2CTXINUSE,
;                 I2CTxLen, I2CTXBUFFLEN, I2CU_CTLW0, I2CU_I2CSA, I2CU_IE, I2CU_IFG
; OTHER FUNCS   : None
I2CStartTx:	CMP		#00080h,R4				;The slave address cannot be greater than 7 bits
			JHS		I2CTxError				;Signal the error and exit
			CMP		#00100h,R5				;The number of bytes cannot be grater than 8 bits
			JHS		I2CTxError				;Signal the error and exit
			BIT		#I2CBUZY,&I2CStatus		;Is the bus buzy?
			JZ		I2CSTTTx				;No => Start the communication at once
			BIC		#UCTXIE0,&I2CU_IE		;Disable transmission interrupt
			BIT		#I2CTXINUSE | I2CRXINUSE,&I2CStatus	;is the transmission sybsystem in use?
			JNZ		I2CTxSchdSt				;Yes => then schedule the transmission
			CMP		#00000h,&I2CTxLen		;Is there any scheduled data to be transmitted?
			JNZ		I2CTxSchdSt				;Yes => Schedule this transmission
			;At this point, either the bus is free, or it expects data to be transmitted (all
			; the previous scheduled data were transmitted and wait for the next action).
			; The bus must be used at once
I2CSTTTx:	BIS		#UCSWRST,&I2CU_CTLW0	;Keep subsystem in reset mode to configure it
			MOV		R5,&I2CU_TBCNT			;Set the byte counter
			BIC		#UCSWRST,&I2CU_CTLW0	;Release the bus subsystem
			MOV		R4,&I2CU_I2CSA			;Set the slave address to be transmitted
			BIS		#UCTR,&I2CU_CTLW0		;Going to transmit data to the slave
			BIS		#UCTXSTT,&I2CU_CTLW0	;Generate the Start condition and send the address
			BIS		#I2CBUZY | I2CTRANSMIT | I2CTXINUSE,&I2CStatus
											;The bus now is buzy transmitting data
			BIS		#UCTXIE0|UCSTPIE|UCNACKIE|UCBCNTIE,&I2CU_IE	;Enable the needed interrupts
			CLRC							;Clear carry to signal success
			RET

I2CTxSchdSt:;The bus should schedule the byte, by adding it in the transmission buffer. This
			; is a critical task, as a running interrupt could alter the results and create a
			; lockup making the bus unusable. So, at this point the Tx interrupt must be
			; disabled
			;The stored word in buffer contains the UCTR bit needed at its MSb, and the 7 bits
			; of the Slave address to communicate at the following 7 bits, completing the MSB
			; of the stored word. The LSB is used to store the coutner of bytes, but in case
			; of Master - Transmitter it is not used
			SWPB	R4						;Bring Slave Address to MSB (Lower 7 bits)
			BIS		#I2CB_UCTR,R4			;Set that this is a starting condition of the
											; Tx communication
			ADD		R5,R4					;Add the number of bytes for the threshold
I2CTx_Schd:	PUSH	SR						;Store the general interrupts status
			DINT							;Disable them. The following part is critical
			NOP
			CMP		#I2CTXBUFFLEN,&I2CTxLen	;Is there any empty cell in buffer?
			JHS		I2CTxStErr				;No => Flag the error and exit
			MOV		&I2CTxStrt,R15			;Get the starting of the cyclic buffer
			ADD		&I2CTxLen,R15			;Add the stored data in it to find the first empty
											; cell
			CMP		#I2CTXBUFFLEN,R15		;Passed the end of the buffer?
			JLO		I2CTxNoRvrt				;No => then do not revert to the beginning
			SUB		#I2CTXBUFFLEN,R15		;else, revert to the beginning
I2CTxNoRvrt:
			ADD		#I2CTxBuff,R15			;R15 points to the first empty cell to be used
			MOV		R4,0(R15)				;Store the whole word of data + flags
			INCD	&I2CTxLen				;Increase the occupied length in buffer (Word)
			POP		SR						;Restore interrupts status
			CLRC							;Clear carry to flag success
			BIS		#UCTXIE0,&I2CU_IE		;Enable transmission interrupt again
			RET
										
I2CTxStErr:	;Buffer is full. The starting slave address is not scheduled => Error
			POP		SR						;Restore general interrupt status
			BIS		#UCTXIE0,&I2CU_IE		;Enable the transmission interrupt
I2CTxError:	SETC							;Set carry flag to express there was an error
			RET
			

;----------------------------------------
; I2CSend
; Sends a byte when the I2C subsystem is configured as a transmitter
; INPUT         : R4 contains the byte to be transmitted
; OUTPUT        : If everything is fine, the carry flag is cleared. If the data byte is not
;                 sent and it is not scheduled (i.e. not valid Start Condition before) the
;                 Carry Flag is set
; REGS USED     : R4, R15 (Through I2CTx_Schd)
; REGS AFFECTED : R4, R15
; STACK USAGE   : 2 (by I2CTx_Schd)
; VARS USED     : I2CBUZY, I2CRXINUSE, I2CStatus, I2CTRANSMIT, I2CTXBUF, I2CTXINUSE, I2CTxLen,
;                 I2CU_IE, I2CU_IFG
; OTHER FUNCS   : I2CTx_Schd, I2CTxError
I2CSend:	;In order to send a byte, the bus must be in Buzy mode (a transaction must have
			; started before, using a Start Condition) and act as a Transmitter. Otherwise it
			; is illegal to send a byte
			BIT		#I2CBUZY,&I2CStatus		;Is the bus buzy?
			JZ		I2CTxError				;No => Signal the error
			BIT		#I2CTRANSMIT,&I2CStatus	;Is the Master acting as a Transmitter?
			JZ		I2CTxError				;No => Illegal again...
			BIC		#UCTXIE0,&I2CU_IE		;Disable transmission interrupt
			BIT		#I2CTXINUSE | I2CRXINUSE,&I2CStatus	;is the transmission sybsystem in use?
			JNZ		I2CTxSchdD				;Yes => then schedule the transmission
			CMP		#00000h,&I2CTxLen		;Is there any scheduled data to be transmitted?
			JNZ		I2CTxSchdD				;Yes => Schedule this transmission

I2CTxNow:	;At this point, either the bus is free, or it expects data to be transmitted (all
			; the previous scheduled data were transmitted and be ready for the next action).
			; The bus must be used at once
			BIS		#I2CTXINUSE,&I2CStatus	;Flag that the transmitter is in use now
			MOV.B	R4,&I2CU_TXBUF			;Send it at once
			BIS		#UCTXIE0,&I2CU_IE		;Enable the transmission interrupt
			CLRC							;Clear carry flag to signal the validity
			RET

I2CTxSchdD:	;The system should schedule the byte, by adding it in the transmission buffer.
			; This is a critical task, as a running interrupt could alter the results and
			; create a lockup making the bus unusable. So, at this point the interrupts must
			; be disabled
			AND		#000FFh,R4				;Ensure higher byte of R4 is cleared as this is
											; pure data
			JMP		I2CTx_Schd				;Schedule the new data to be transmitted later


;----------------------------------------
; I2CStop
; Sends a Stop condition through the I2C bus
; INPUT         : None
; OUTPUT        : If everything is fine, the carry flag is cleared. If the condition is not
;                 sent and it is not scheduled, or a valid transaction was not started, the
;                 Carry Flag is set to indicate there was an error
; REGS USED     : R4, R15 (by I2CTx_Schd)
; REGS AFFECTED : R4, R15 (by I2CTx_Schd)
; STACK USAGE   : 2 (by I2CTx_Schd)
; VARS USED     : I2CB_UCTR, I2CU_CTLW0, I2CBUZY, I2CRXINUSE, I2CStatus, I2CTXBUF, I2CTXINUSE,
;                 I2CTxLen, I2CU_IE, I2CU_IFG
; OTHER FUNCS   : I2CTx_Schd
I2CStop:	BIT		#I2CBUZY,&I2CStatus		;Is the bus buzy?
			JZ		I2CTxError				;No => Illegal to send a Stop Condition
			BIC		#UCTXIE0,&I2CU_IE		;Disable transmission interrupt
			BIT		#I2CTXINUSE | I2CRXINUSE,&I2CStatus	;is the transmission sybsystem in use?
			JNZ		I2CSpSchdD				;Yes => then schedule the transmission
			CMP		#00000h,&I2CTxLen		;Is there any scheduled data to be transmitted?
			JNZ		I2CSpSchdD				;Yes => Schedule this transmission

I2CStpTxNow:;At this point, either the bus is free, or it expects data to be transmitted (all
			; the previous scheduled data were transmitted and the system waits for the next
			; action). The bus must be used at once
			BIS		#UCTXSTP,&I2CU_CTLW0	;Generate the Stop Condition
			BIS		#UCSTPIFG,&I2CU_IE		;Enable the Stop Condition Interrupt
			CLRC							;Signal everything is OK
			RET

I2CSpSchdD:	;The bus should schedule the transaction, by adding it in the transmission buffer
			; an empty byte with the stop condition flag set. This is a critical task, as a
			; running interrupt could alter the results and create a lockup making the bus
			; unusable. So, at this point the interrupts must be disabled
			MOV		#I2CB_UCTR,R4			;Set R4 with empty data and Stop Condition flag
			JMP		I2CTx_Schd				;Schedule the new data to be transmitted later


;----------------------------------------
; I2CStartRx
; Produces a Start condition on I2C bus and sends the Address byte. The bus is configured in
; Receiver mode, so it expects to receive data from the slave
; INPUT         : R4 contains the Slave to be addressed
;               : R5 contains the number of bytes to fetch from the slave
; OUTPUT        : Carry Flag reflects if there was an error (when set)
; REGS USED     : R4, R5, R15
; REGS AFFECTED : R4, R15
; STACK USAGE   : 2 (by I2CTx_Schd)
; VARS USED     : I2CBUZY, I2CRXINUSE, I2CStatus, I2CTRANSMIT, I2CTXINUSE, I2CU_CTLW0,
;                 I2CU_I2CSA, I2CU_IE, I2CU_IFG, I2CU_TBCNT
; OTHER FUNCS   : I2CTx_Schd
I2CStartRx:	CMP		#00080h,R4				;An address cannot exceed 7 bits
			JHS		I2CTxError				;Flag the error
			CMP		#00100h,R5				;The number of bytes to be received cannot exceed
			JHS		I2CTxError				; 8 bits, so in that case flag the error
			BIT		#I2CBUZY,&I2CStatus		;Is the bus buzy?
			JZ		I2CSTTRx				;No => Start the communication at once
			BIC		#UCTXIE0,&I2CU_IE		;Disable transmission interrupt
			BIT		#I2CTXINUSE | I2CRXINUSE,&I2CStatus	;is the transmission sybsystem in use?
			JNZ		I2CRxSchdSt				;Yes => then schedule the transmission

			CMP		#00000h,&I2CTxLen		;Is there any scheduled data to be transmitted?
			JNZ		I2CRxSchdSt				;Yes => Schedule this transmission

I2CSTTRx:	;At this point, either the bus is free, or it expects data to be transmitted (all
			; the previous scheduled data were transmitted and waits for the next action).
			; The bus must be used at once
			BIS		#UCSWRST,&I2CU_CTLW0	;Keep I2C bus in reset mode, to set it up
			MOV		R5,&I2CU_TBCNT			;Set the counter of bytes
			BIC		#UCSWRST,&I2CU_CTLW0	;Release the bus
			MOV		R4,&I2CU_I2CSA			;Set the slave address to be transmitted
			BIC		#UCTR,&I2CU_CTLW0		;Going to receive data from the slave
			BIS		#I2CBUZY | I2CRXINUSE,&I2CStatus	;Flag that the bus is buzy
			BIC		#I2CTRANSMIT,&I2CStatus	;In Receiver mode
											;The bus now is buzy transmitting data
			BIS		#UCTXSTT,&I2CU_CTLW0	;Generate the Start condition and send the address
			BIS		#UCTXIE0 | UCRXIE0 | UCNACKIE | UCBCNTIE | UCSTPIE,&I2CU_IE;Enable ints.
			CLRC
			RET

I2CRxSchdSt:;The bus should schedule the transaction, by adding it in the transmission buffer.
			; The word that should be scheduled, contains the slave addres at its higher byte,
			; together with the receive flag. In the lower byte of the scheduled word there is
			; the threshold count of bytes to be received. No automatic Stop Condition is sent
			; automatically. This is a critical task, as a running interrupt could alter the
			; results and create a lockup making the bus unusable. So, at this point the
			; interrupts must be disabled
			SWPB	R4						;Slave address to its higher byte
			ADD		R5,R4					;Number of bytes to the lower byte
											;I2CB_UCTR bit is 0 to signal Receive mode
			JMP		I2CTx_Schd				;Schedule the new data to be transmitted later


;----------------------------------------
; I2CReadBuf
; Reads a byte from the reception buffer, if there is any
; INPUT         : None
; OUTPUT        : R4 contains the byte read from I2C Reception Buffer. If there was no data
;                  available, R4 is reset and Carry Flag is set.
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : 
; OTHER FUNCS   : None
I2CReadBuf:	MOV.B	#000h,R4
			CMP		#00000h,&I2CRxLen
			JNE		I2CRxNo
			PUSH	SR						;Store the state of the interrupts
			DINT							;Disable them. The following is a critical section
			NOP
			MOV		&I2CRxStrt,R4			;Get the starting pointer
			ADD		#I2CRxBuff,R4			;Add the starting offset of the buffer
			MOV.B	@R4,R4					;Get the byte from the buffer
			DEC		&I2CRxLen				;One byte less in buffer
			POP		SR						;Restore Interrupts
			CLRC							;Clear carry. R4 contains a byte
I2CRxNo:	;SETC							;Came here from a CMP #O,... When 0, the carry
											; flag is set, so no need to do it again here.
											; Added only for clarity
			RET


;----------------------------------------
; I2CGetStatus
; Returns the status word. The input is a flag mask that makes these bits get cleared on exit
; INPUT         : R4 contains the flag mask of the flags to be cleared
; OUTPUT        : R4 contains the status word
; REGS USED     : R4, R5
; REGS AFFECTED : R4, R5
; STACK USAGE   : 2 = 1x Push
; VARS USED     : I2CStatus
; OTHER FUNCS   : None
I2CGetStatus:
			PUSH	SR						;This is a critical section so we have to
			DINT							;Disable interrupts. But first store their status
			NOP
			MOV		R4,R5					;Get the mask
			MOV		&I2CStatus,R4			;Get the status word
			BIC		R5,&I2CStatus			;Clear the bits defined by the mask
			POP		SR						;Re-enable interrups only if they were enabled
			RET								;Return to caller


;----------------------------------------
; Interrupt Service Routines
;========================================
;----------------------------------------
; I2CTxISR
; Interrupt Service Routine for I2C Transmission readiness. The interrupt is triggered by
; UCTXIFG0 flag when its associated interrupt is enabled (UCTXIE0) and the system is ready to
; accept a new data byte to be transmitted. If there is any byte in the buffer it should be
; sent now.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : R4, R15
; REGS AFFECTED : None
; STACK USAGE   : 4 = 2x Push
; VARS USED     : I2CB_UCTR, I2CStatus, I2CTRANSMIT, I2CTxBuf, I2CTXBUFFLEN, I2CTXINUSE,
;                 I2CTxLen, I2CTxStrt, I2CU_CTLW0, I2CU_I2CSA, I2CU_IE, I2CU_TBCNT, I2CU_TXBUF
; OTHER FUNCS   : None
I2CTxISR:	BIC		#I2CTXINUSE,&I2CStatus	;Transmitter for now is free
			CMP		#00000h,&I2CTxLen		;Is there any scheduled data to be transmitted?
			JZ		ITxISREnd				;No => Then exit the interrupt
			PUSH	R4						;Gonna need some registers
			PUSH	R15
			MOV		&I2CTxStrt,R15			;Get the starting offset of the buffer
			MOV		I2CTxBuff(R15),R4		;Get the word scheduled
			INCD	R15						;Point to the next element in buffer
			CMP		#I2CTXBUFFLEN,R15		;Passed the border of the table?
			JLO		ITxNoRvt				;No => do not revert to the beginning
			MOV		#00000h,R15				;else, point to the beginning of the table
ITxNoRvt:	MOV		R15,&I2CTxStrt			;Store the new pointer
			DECD	&I2CTxLen				;One word less in the buffer
;			JNZ		ITxISRKeep				;Still data in buffer? => Keep this ISR enabled
;			BIC		#UCTXIE0,&I2CU_IE		;else, disable it
			;Now R4 contains the data word fetched from Tx Buffer. R4 may contain 0 at its MSB
			; to signal the presence of data at its LSB, or /= 0 to signal a Start/Stop
			; condition to be sent and a counter at its lower byte. Need to figure out if this
			; is data or condition
ITxISRKeep:	BIT		#0FF00h,R4				;Do we have Start/Stop Condition?
			JZ		ITxISRDat				;No => then send pure data
			BIT		#(~I2CB_UCTR & 0FF00h),R4	;Do we have to send a Start Condition? 
			JNZ		ITxISRStt				;Yes => Send a reStart Condition
ITxISRStp:	;When a Stop Condition is scheduled, the lower byte of R4 is irrelevant
			BIS		#UCTXSTP,&I2CU_CTLW0	;Send the Stop Condition (and wait for its
											; interrupt)
			POP		R15						;Restore used registers
			POP		R4
;			BIC		#UCTXIE0,&I2CU_IE		;Disable transmission interrupt

ITxISREnd:
			RETI
			
ITxISRDat:	;Just a clear byte to send
			MOV.B	R4,&I2CU_TXBUF			;Go!...
			BIS		#I2CTXINUSE,&I2CStatus	;Flag that the transmitter is in use now
			POP		R15						;And exit, restoring the used registers
			POP		R4
			RETI
			
ITxISRStt:	;If a Start Condition is scheduled then R4 at its LSB contains the number of bytes
			; of the threshold, the slave to be addressed at its higher byte together with the
			; UCTR flag
			BIS		#UCSWRST,&I2CU_CTLW0	;Keep the bus in reset
			MOV		R4,R15					;Need to filter only the coutner (LSB), so copy
			AND		#000FFh,R15				;... filter ...
			MOV		R15,&I2CU_TBCNT			;Set the threshold
			BIC		#UCSWRST | UCTR,&I2CU_CTLW0	;Release the I2C subsystem
			BIC		#I2CTRANSMIT,&I2CStatus	;Assume Receive mode
			BIT		#I2CB_UCTR,R4			;Transmit or receive mode?
			JZ		ITxSttRx				;Receive Mode, then do not alter UCTR
			BIS		#UCTR,&I2CU_CTLW0		;else, set the transmitter mode
			BIS		#I2CTRANSMIT,&I2CStatus	;Set also the flags of the status word
ITxSttRx:	SWPB	R4						;Bring the slave address to LSB
			AND		#0007Fh,R4				;Filter out all the other bits
			MOV.B	R4,&I2CU_I2CSA			;Set the slave address
			BIS		#UCTXSTT,&I2CU_CTLW0	;Send the Start Condition and the slave address
			BIS		#UCRXIE0 | UCTXIE0 | UCBCNTIE | UCNACKIE | UCSTPIE,&I2CU_IE	;Enable ints
			POP		R15						;And exit, restoring the used registers
			POP		R4
			RETI


;----------------------------------------
; I2CStpISR
; Interrupt Service Routine for I2C Stop condition. The interrupt is triggered by UCSTPIFG0
; flag when its associated interrupt is enabled (UCSTPIE0) and a Stop Condition is met or
; transmitted. Another transaction is finished. Must see if there is any other transaction is
; scheduled, to send a Start Condition and start a new transaction.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : R4, R15
; REGS AFFECTED : None
; STACK USAGE   : 4 = 2x Push
; VARS USED     : I2CB_UCTR, I2CPRESTOP, I2CRXINUSE, I2CStatus, I2CTxBuff, I2CTXBUFFLEN,
;                 I2CTXINUSE, I2CTxLen, I2CTxStrt, I2CU_CTLW0, I2CU_I2CSA, I2CU_IE, I2CU_TBCNT
; OTHER FUNCS   : None
I2CStpISR:	;Normally we should clear the Busy flag in I2C Status variable. But first, lets
			; see if there is any other transaction scheduled to start it at once
			BIC		#LPM4,0(SP)				;Going to wake the system up to handle the
											; communication ending
			CMP		#00000h,&I2CTxLen		;Is there any other transaction scheduled?
			JZ		IStpIEnd				;No => Bus is totally free now
			;Need to send the next Start Condition scheduled
			PUSH	R4						;Going to use some registers
			PUSH	R15
			JMP		IStrIFtch
IStrCSkip:	BIS		#I2CPRESTOP,&I2CStatus	;Set the error of Pre-Stop in I2C Status flags
			CMP		#00000h,&I2CTxLen		;Is there any other transaction scheduled?
			JZ		IStpIEnd				;No => Bus is totally free now
IStrIFtch:	MOV		&I2CTxStrt,R15			;Get the starting offset, in Tx buffer
			MOV		I2CTxBuff(R15),R4		;Get the first word in queue
			INCD	R15						;Advance to next cell
			CMP		#I2CTXBUFFLEN,R15		;Passed the border?
			JLO		IStrISkip				;No => Skip reverting to the beginning
			MOV		#00000h,R15				;else, return to the beginning of the buffer
IStrISkip:	MOV		R15,&I2CTxStrt			;Store the new pointer
			DECD	&I2CTxLen				;One word less in buffer
			BIT		#0FF00h,R4				;Is there a Start Condition?
			JZ		IStrCSkip				;No => error, skip this byte
			MOV		R4,R15					;Get a copy of the Slave address
			AND		#00FFh,R15				;Filter only the threshold counter
			BIS		#UCSWRST,&I2CU_CTLW0	;Keep bus in reset mode
			MOV		R15,&I2CU_TBCNT			;Set it
			BIC		#UCSWRST|UCTR,&I2CU_CTLW0;Release the bus assuming Receiver mode
			BIC		#I2CTRANSMIT,&I2CStatus	;Flag that we are in receiver mode
			BIS		#I2CRXINUSE,&I2CStatus	;also, receiver is in use
			BIT		#I2CB_UCTR,R4			;Transmitter mode?
			JZ		IStrITrOK				;No => then we are OK
			BIS		#UCTR,&I2CU_CTLW0		;Else set the transmitter mode bit
			BIS		#I2CTRANSMIT | I2CTXINUSE,&I2CStatus ;Going to be a transmitter
			BIC		#I2CRXINUSE,&I2CStatus
IStrITrOK:	SWPB	R4						;Bring the slave address to LSB
			AND		#0007Fh,R4				;Filter only the slave address
			MOV		R4,&I2CU_I2CSA			;Set the Slave Address
			BIS		#UCTXSTT,&I2CU_CTLW0	;Send the Start Condition
			BIS		#UCTXIE0 | UCRXIE0 | UCNACKIE | UCSTPIE | UCBCNTIE,&I2CU_IE
			POP		R15						;Enable I2C Interrupts and restore the used
			POP		R4						; registers
			RETI
			
IStpIExit:	POP		R15						;Restore used registers
			POP		R4
IStpIEnd:	;Nothing to do at this point. The bus should become free
			BIC		#I2CBUZY | I2CTRANSMIT | I2CRXINUSE | I2CTXINUSE,&I2CStatus	;Clear status
			BIC		#UCTXIE0 | UCRXIE0 | UCSTPIE | UCNACKIE | UCBCNTIE,&I2CU_IE	;Disable Ints
			RETI


;----------------------------------------
; I2CNAckISR
; Interrupt Service Routine for I2C NAck. When a NAck is received the communication should be
; stopped. Also, the main thread should be notified, so the system wakes up
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : 2 (By call)
; VARS USED     : I2CNACKRECV, I2CStatus
; OTHER FUNCS   : I2CStpTxNow
I2CNAckISR:	BIS		#I2CNACKRECV,&I2CStatus	;Flag there is a NAck received
			CALL	#I2CStpTxNow			;Send a Stop condition
			BIC		#LPM4,0(SP)				;Wake up the system on exit
			RETI							;Return to interrupted process. The Stop interrupt
											; will be triggered after the condition is sent


;----------------------------------------
; I2CBcntISR
; Interrupt Service Routine for I2C Threshold counter. It is triggered whenever the threshold
; counter is reached, meaning all the bytes expected were transmitted or received. The only
; thing this interrupt does is to wake the system up. The main thread can then fetch the
; received data, or act according to the status
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
I2CBcntISR:
			BIC		#I2CRXINUSE,&I2CStatus	;Receiver is free now (no more bytes to receive)
			BIS		#I2CCOUNTOK,&I2CStatus	;Set the counter flag
			RETI


;----------------------------------------
; I2CRxISR
; Interrupt Service Routine for data reception. Whenever there is a new byte in the receiving
; buffer of I2C hardware subsystem, this interrupt is triggered. The already came byte must be
; copied to the receiving circular buffer. When the buffer reaches its threshold the system
; wakes up to consume these data, and empty the buffer to be able to receive more.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : R4, R15
; REGS AFFECTED : None
; STACK USAGE   : 4 = 2x Push
; VARS USED     : I2CRxBuff, I2CRXBUFFLEN, I2CRXFULL, I2CRxLen, I2CRXLIMIT, I2CRXOVFL,
;                 I2CRxStrt, I2CRXTHRESHOLD, I2CStatus, I2CU_RXBUF,
; OTHER FUNCS   : None
I2CRxISR:	PUSH	R4
			MOV.B	&I2CU_RXBUF,R4			;Get the byte as soon as possible cause hardware
											; is still active
			PUSH	R15
			MOV		&I2CRxLen,R15			;Get the length of the occupied cyclic buffer
			CMP		#I2CRXBUFFLEN,R15		;Is the receiving buffer full?
			JHS		IRxIOvfl				;Signal that buffer is overflowed
			ADD		&I2CRxStrt,R15			;Add the starting offset
			CMP		#I2CRXBUFFLEN,R15		;Passed the end of buffer?
			JLO		IRxISkipRvt				;No => Do not revert to its begining
			SUB		#I2CRXBUFFLEN,R15		;Revert to its beginning
IRxISkipRvt:MOV.B	R4,I2CRxBuff(R15)		;Store the new byte in receiver buffer
			MOV		&I2CRxLen,R15			;Get the stored length in buffer
			INC		R15						;One byte more in buffer
			MOV		R15,&I2CRxLen			;Store the new value
			CMP		#I2CRXBUFFLEN,R15		;Reached the limit?
			JLO		IRxINoFull				;No => do not set the flag
			BIS		#I2CRXFULL,&I2CStatus	;else, set it
IRxINoFull:	CMP		#I2CRXTHRESHOLD,R15		;Did we reach the threshold limit?
			JLO		IRxINoLimit				;No => then we are inside valid margins
			BIS		#I2CRXLIMIT,&I2CStatus	;Flag that we reached the threshold limit
IRxIExit:	BIC		#LPM4,4(SP)				;Wake the system up on exit
IRxINoLimit:;In case of a jump to No Limit, the system does not have to wake up, so just exit
			POP		R15						;Restore used registers
			POP		R4
			RETI

IRxIOvfl:	;No attempt were made to store the newlly came byte, as there is no room in the
			; receive buffer. Flag the error and wake the system up to handle it
			BIS		#I2CRXOVFL,&I2CStatus	;Receiver System Overflow
			JMP		IRxIExit


;----------------------------------------
; I2CDispatcher
; Interrupt Service Routine for I2C eUSCI. It dispatches to the appropriate function according
; to the Interrupt Vector that triggered the interrupt
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : I2CU_IV
; OTHER FUNCS   : I2CNAckISR, I2CRxISR, I2CStpISR, I2CTxISR
I2CDispatcher:
			ADD		&I2CU_IV,PC				;Proceed to appropriate Jump
			RETI							;Vector 0: No Interrupt
			RETI							;Vector 2: Arbitration Lost (ALIFG)
			JMP		I2CNAckISR				;Vector 4: Not Acknowledge received (NACKIFG)
			RETI							;Vector 6: Start Condition met (Slave, STTIFG)
			JMP		I2CStpISR				;Vector 8: Stop Condition met (STPIFG)
			RETI							;Vector 10: RXIFG3
			RETI							;Vector 12: TXIFG3
			RETI							;Vector 14: RXIFG2
			RETI							;Vector 16: TXIFG2
			RETI							;Vector 18: RXIFG1
			RETI							;Vector 20: TXIFG1
			JMP		I2CRxISR				;Vector 22: Byte received (RXIFG0)
			JMP		I2CTxISR				;Vector 24: Byte transmitted (TXIFG0)
			JMP		I2CBcntISR				;Vector 26: Byte Counter interrupt (BCNTIFG)
			RETI							;Vector 28: Clock Low Timeout (CLTOIFG)
			RETI							;Vector 30: 9th Bit Transferring (BIT9IFG)
			

;----------------------------------------
; Interrupt Vectors
;========================================
			.sect	I2CU_Vector
			.short	I2CDispatcher
