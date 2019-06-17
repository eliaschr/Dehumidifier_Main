;*********************************************************************************************
;* NTC Library                                                                               *
;*-------------------------------------------------------------------------------------------*
;* NTC_Table.asm                                                                             *
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
;* Constant data table of ADC values and respective temperature readings. The first column   *
;* contains the ADC value and the second column contains the respective temperature,         *
;* multiplied by 10 to contain one decimal digit of the fractional part of the number.       *
;* The data in this table were calculated using NTC Calculator of Vishay, and Excel. They    *
;* are for NTCLE300E3302SB NTC sensor.                                                       *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"NTC Library"
			.width	94
			.tab	4

;*===========================================================================================*
;* Names And Values:                                                                         *
;* ------------------                                                                        *
;* NTC_Table     : Contains the values to convert ADC readings to Temperature                *
;* NTC_Table_END : Points to the end of the table. The function that scans the table needs   *
;*                  know its end.                                                            *
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

;The table and its end must be global in order for the rest program to access it
			.global	NTC_Table
			.global	NTC_Table_END


;----------------------------------------
; Constants
;========================================
			.sect	".const"

NTC_Table:
			.word		373,-400
			.word		384,-395
			.word		396,-390
			.word		408,-385
			.word		420,-380
			.word		433,-375
			.word		445,-370
			.word		458,-365
			.word		472,-360
			.word		485,-355
			.word		499,-350
			.word		513,-345
			.word		528,-340
			.word		543,-335
			.word		558,-330
			.word		573,-325
			.word		589,-320
			.word		605,-315
			.word		621,-310
			.word		637,-305
			.word		654,-300
			.word		671,-295
			.word		689,-290
			.word		707,-285
			.word		725,-280
			.word		743,-275
			.word		762,-270
			.word		781,-265
			.word		800,-260
			.word		819,-255
			.word		839,-250
			.word		859,-245
			.word		880,-240
			.word		900,-235
			.word		921,-230
			.word		942,-225
			.word		964,-220
			.word		986,-215
			.word		1008,-210
			.word		1030,-205
			.word		1052,-200
			.word		1075,-195
			.word		1098,-190
			.word		1121,-185
			.word		1145,-180
			.word		1168,-175
			.word		1192,-170
			.word		1216,-165
			.word		1240,-160
			.word		1265,-155
			.word		1290,-150
			.word		1314,-145
			.word		1339,-140
			.word		1365,-135
			.word		1390,-130
			.word		1415,-125
			.word		1441,-120
			.word		1467,-115
			.word		1492,-110
			.word		1518,-105
			.word		1544,-100
			.word		1570,-95
			.word		1597,-90
			.word		1623,-85
			.word		1649,-80
			.word		1676,-75
			.word		1702,-70
			.word		1729,-65
			.word		1755,-60
			.word		1782,-55
			.word		1808,-50
			.word		1835,-45
			.word		1861,-40
			.word		1888,-35
			.word		1914,-30
			.word		1941,-25
			.word		1967,-20
			.word		1993,-15
			.word		2019,-10
			.word		2046,-5
			.word		2072,0
			.word		2098,5
			.word		2124,10
			.word		2149,15
			.word		2175,20
			.word		2201,25
			.word		2226,30
			.word		2251,35
			.word		2277,40
			.word		2302,45
			.word		2327,50
			.word		2351,55
			.word		2376,60
			.word		2400,65
			.word		2424,70
			.word		2448,75
			.word		2472,80
			.word		2496,85
			.word		2519,90
			.word		2543,95
			.word		2566,100
			.word		2588,105
			.word		2611,110
			.word		2634,115
			.word		2656,120
			.word		2678,125
			.word		2699,130
			.word		2721,135
			.word		2742,140
			.word		2763,145
			.word		2784,150
			.word		2805,155
			.word		2825,160
			.word		2845,165
			.word		2865,170
			.word		2885,175
			.word		2904,180
			.word		2923,185
			.word		2942,190
			.word		2961,195
			.word		2979,200
			.word		2997,205
			.word		3015,210
			.word		3033,215
			.word		3051,220
			.word		3068,225
			.word		3085,230
			.word		3101,235
			.word		3118,240
			.word		3134,245
			.word		3150,250
			.word		3166,255
			.word		3182,260
			.word		3197,265
			.word		3212,270
			.word		3227,275
			.word		3242,280
			.word		3256,285
			.word		3270,290
			.word		3284,295
			.word		3298,300
			.word		3312,305
			.word		3325,310
			.word		3338,315
			.word		3351,320
			.word		3364,325
			.word		3376,330
			.word		3388,335
			.word		3401,340
			.word		3412,345
			.word		3424,350
			.word		3436,355
			.word		3447,360
			.word		3458,365
			.word		3469,370
			.word		3480,375
			.word		3490,380
			.word		3501,385
			.word		3511,390
			.word		3521,395
			.word		3531,400
			.word		3541,405
			.word		3550,410
			.word		3559,415
			.word		3569,420
			.word		3578,425
			.word		3587,430
			.word		3595,435
			.word		3604,440
			.word		3612,445
			.word		3621,450
			.word		3629,455
			.word		3637,460
			.word		3645,465
			.word		3652,470
			.word		3660,475
			.word		3667,480
			.word		3675,485
			.word		3682,490
			.word		3689,495
			.word		3696,500
			.word		3703,505
			.word		3709,510
			.word		3716,515
			.word		3722,520
			.word		3729,525
			.word		3735,530
			.word		3741,535
			.word		3747,540
			.word		3753,545
			.word		3758,550
			.word		3764,555
			.word		3770,560
			.word		3775,565
			.word		3781,570
			.word		3786,575
			.word		3791,580
			.word		3796,585
			.word		3801,590
			.word		3806,595
			.word		3811,600
			.word		3816,605
			.word		3820,610
			.word		3825,615
			.word		3829,620
			.word		3834,625
			.word		3838,630
			.word		3842,635
			.word		3846,640
			.word		3850,645
			.word		3854,650
			.word		3858,655
			.word		3862,660
			.word		3866,665
			.word		3870,670
			.word		3873,675
			.word		3877,680
			.word		3881,685
			.word		3884,690
			.word		3887,695
			.word		3891,700
			.word		3894,705
			.word		3897,710
			.word		3901,715
			.word		3904,720
			.word		3907,725
			.word		3910,730
			.word		3913,735
			.word		3916,740
			.word		3918,745
			.word		3921,750
			.word		3924,755
			.word		3927,760
			.word		3929,765
			.word		3932,770
			.word		3935,775
			.word		3937,780
			.word		3940,785
			.word		3942,790
			.word		3944,795
			.word		3947,800
			.word		3949,805
			.word		3951,810
			.word		3954,815
			.word		3956,820
			.word		3958,825
			.word		3960,830
			.word		3962,835
			.word		3964,840
			.word		3966,845
			.word		3968,850
			.word		3970,855
			.word		3972,860
			.word		3974,865
			.word		3976,870
			.word		3977,875
			.word		3979,880
			.word		3981,885
			.word		3983,890
			.word		3984,895
			.word		3986,900
			.word		3988,905
			.word		3989,910
			.word		3991,915
			.word		3992,920
			.word		3994,925
			.word		3995,930
			.word		3997,935
			.word		3998,940
			.word		4000,945
			.word		4001,950
			.word		4003,955
			.word		4004,960
			.word		4005,965
			.word		4007,970
			.word		4008,975
			.word		4009,980
			.word		4010,985
			.word		4012,990
			.word		4013,995
			.word		4014,1000
			.word		4015,1005
			.word		4016,1010
			.word		4017,1015
			.word		4018,1020
			.word		4020,1025
			.word		4021,1030
			.word		4022,1035
			.word		4023,1040
			.word		4024,1045
			.word		4025,1050
			.word		4026,1055
			.word		4027,1060
			.word		4028,1065
			.word		4029,1070
			.word		4030,1075
			.word		4031,1085
			.word		4032,1090
			.word		4033,1095
			.word		4034,1100
			.word		4035,1105
			.word		4036,1110
			.word		4037,1120
			.word		4038,1125
			.word		4039,1130
			.word		4040,1135
			.word		4041,1145
			.word		4042,1150
			.word		4043,1155
			.word		4044,1165
			.word		4045,1170
			.word		4046,1180
			.word		4047,1185
			.word		4048,1195
			.word		4049,1200
			.word		4050,1210
			.word		4051,1220
			.word		4052,1225
			.word		4053,1235
			.word		4054,1245
			.word		4055,1255
			.word		4056,1265
			.word		4057,1275
			.word		4058,1285
			.word		4059,1295
			.word		4060,1305
			.word		4061,1315
			.word		4062,1330
			.word		4063,1340
			.word		4064,1350
			.word		4065,1365
			.word		4066,1380
			.word		4067,1390
			.word		4068,1405
			.word		4069,1420
			.word		4070,1440
			.word		4071,1455
			.word		4072,1470
			.word		4073,1490
NTC_Table_END:
			.word		-1,-1
