#this version has two interrupt one for timer and one for sensor

.equ ADDR_PUSHBUTTONS, 0xFF200050 # Address Pushbuttons
.equ ADDR_JP1, 0xFF200060   # Address GPIO JP1
.equ ADDR_JP1_IRQ, 0x0800      # IRQ line for GPIO JP1 (IRQ11)
.equ TIMER1, 0xFF202000 # Address TIMER1, used to polling in interrupt mode
.equ TIMER2, 0xFF202020   # Address TIMER2, used for controlling the speed of lego car
# PERIOD1 and PERIOD2 are used to slow down lego car's movement both in interrupt mode and non-interrupt mode
.equ PERIOD1, 75000 # time period for turning motor on (used for moving forward)
.equ PERIOD2, 160000 # time period for turning motor off (used for moving forward)
.equ PERIOD3, 300000 # time period for turning motor on (used for turnig)
.equ PERIOD4, 100000 # time period for turning motor off (used for turnig)
.equ PERIOD5, 75000000 # time period for turning motor on (used for moving backward)
.equ PERIOD6, 75000000 # time period for turning motor off (used for moving backward)
.equ PERIOD7, 150000000 # time period for turning motor on (used for turning after moving backward)

.text

.global main

main:
start:
#		call InitTimer1
#       call InitTimer2
        call InitMotors
        movia  r10, ADDR_JP1_IRQ    # enable interrupt for GPIO JP1 (IRQ11)
        wrctl  ctl3, r10
        movia  r10, 1
        wrctl  ctl0, r10            # enable global interrupts
LOOP:
		movui r4, %lo(PERIOD1)
		movui r5, %hi(PERIOD1)
		call StartTimer2
		call TURN_OFF_MOTOR
		movui r4, %lo(PERIOD2)
		movui r5, %hi(PERIOD2)
		call StartTimer2
		call TURN_ON_MOTOR
        br LOOP

# InitTimer1:
        # movia r8,TIMER1
        # movui r9,%lo(PERIOD1)
        # stwio r9,8(r8) # low 16bits
        # movui r9,%hi(PERIOD1)
        # stwio r9,12(r8) # high 16bits
        # stwio r0,0(r8) # clear the timer
        # ret

# InitTimer2:
        # movia r8,TIMER2
        # movui r9,%lo(PERIOD2)
        # stwio r9,8(r8) # low 16bits
        # movui r9,%hi(PERIOD2)
        # stwio r9,12(r8) # high 16bits
        # stwio r0,0(r8) # clear the timer
        # movi r10,0b111 #start timer, continuous, interrupt enabled
        # stwio r10,4(r8) #enable timer interrupt
        # ret

InitMotors:
        movia r8, ADDR_JP1
        movia r9, 0x07f557ff       # set direction for motors to all output 
        stwio r9, 4(r8)
        # load sensor0 threshold value 9 and enable sensor0
        movia  r9,  0xFCBFFBFF       # set motors off enable threshold load sensor 0
        stwio  r9,  0(r8)            # store value into threshold register
        # load sensor1 threshold value 9 and enable sensor1
        movia  r9,  0xFCBFEFFF       # set motors off enable threshold load sensor 1
        stwio  r9,  0(r8)            # store value into threshold register
        # load sensor2 threshold value 9 and enable sensor2
        movia  r9,  0xFCBFBFFF       # set motors off enable threshold load sensor 2
        stwio  r9,  0(r8)            # store value into threshold register
        # load sensor3 threshold value 9 and enable sensor3
        movia  r9,  0xFCBEFFFF       # set motors off enable threshold load sensor 3
        stwio  r9,  0(r8)            # store value into threshold register
        # disable threshold register and enable state mode
        movia  r9,  0xfadffff0      # keep threshold value same in case update occurs before state mode is enabled, and enable motor 0 and motor 1 to be forward
        stwio  r9,  0(r8)
        # enable interrupts
        movia  r9, 0x18000000       # enable interrupts on sensor0, sensor1
        stwio  r9, 8(r8)
        ret
		
TURN_ON_MOTOR:
		movia r17, ADDR_JP1
		ldwio r18, 0(r17)
		movia r19, 0xfffffc00 # get mask for previous state except for the motors
		and r18, r18, r19
		movia r19, 0x0000003f0
		or r20, r18, r19
		stwio r20, 0(r17)
		ret
		
TURN_OFF_MOTOR:
		movia r17, ADDR_JP1
		ldwio r18, 0(r17)
		movia r19, 0xfffffc00 # get mask for previous state except for the motors
		and r18, r18, r19
		movia r19, 0x0000003ff
		or r20, r18, r19
		stwio r20, 0(r17)
		ret

# for not interrupt use
StartTimer2:
        movia r15,TIMER2
        stwio r4,8(r15) # low 16bits
        stwio r5,12(r15) # high 16bits
        movui r16,0x4 # start timer, not continued
        stwio r16,4(r15)

Poll2:   
        ldwio r16,0(r15)
        andi r16,r16,0x1 # check if timer has timed out
        beq r16,r0,Poll2 # loop and check again
        stwio r0,0(r15) # clear the timer
        ret # PERIOD seconds has passed

.section .exceptions, "ax"
IHANDLER:
		# store ra
		addi sp, sp, -8
		stw ra, 0(sp)
		rdctl et, ctl1
		stw et, 4(sp)
        # check to see if sensor0 interrupt happened    
        rdctl et, ctl4
        andi et, et, 0x0800 # check if interrupt pending from IRQ11 (ctl4:bit1)
        beq et, r0, exit# if not sensor0, exit ISR

CHECK_INTER:
        movia r10, ADDR_JP1
		ldwio r11, 12(r10)
        
SENSOR0_INTER:
        movia r12, 0x08000000	# check if interrupt caused by sensor 0 
        and r13, r11, r12
        srli r13, r13, 0x1b		# shift right by 27 bits
		
SENSOR1_INTER:
		movia r12, 0x10000000	# check if interrupt caused by sensor 1
		and r14, r11, r12
		srli r14, r14, 0x1c	# shift right by 28 bits

CHECK_SIMULTANEOUS_INTER:
		and et, r13, r14
#		bne et, r0, STRAIGHT_TURN
		movui r6, %lo(PERIOD3)
		movui r7, %hi(PERIOD3)
		bne r13, r0, MOTOR_TURN_RIGHT
		bne r14, r0, MOTOR_TURN_LEFT
		br exit
		
# 90 degree turn is met, decide which way to turn
STRAIGHT_TURN:
		# movia r12, 0x20000000 	# check if sensor 2 passed its threshold
		# and r13, r11, r12
		# srli r13, r13, 0x1d		# shift right by 29 bits
		# bne r13, r0, MOTOR_MOVE_BACKWARD_R
		# movia r12, 0x40000000	# check if sensor 3 passed its threshold
		# and r13, r11, r12
		# srli r13, r13, 0x1e	# shift right by 30 bits		
		# bne r13, r0, MOTOR_MOVE_BACKWARD_L
		# br STRAIGHT_TURN

        ldwio et, 0(r10)
		movia r11, 0x20000000
		and r11, r11, et
        srli r12, r11, 0x1d # check bit 29 sensor2 (right sensor)
		# r13 used to decide which direction to go
		movi r13, 0x0
        bne r12, r0, MOTOR_MOVE_BACKWARD
				
		movia r11, 0x40000000
		and r11, r11, et
        srli r12, r11, 0x1e # check bit 30 sensor3 (left sensor)
		# r13 used to decide which direction to go
		movi r13, 0x1
        bne r12, r0, MOTOR_MOVE_BACKWARD
        br STRAIGHT_TURN

MOTOR_TURN_LEFT:
		movia r11, 0xfffffc00
		ldwio r12, 0(r10)
		and r11, r11, r12		  # get mask for all the bits except for the motor (first 22 bits)
        movia et, 0x000003fc       # motor0 enabled (bit0=0), direction set to forward (bit1=0) 
		or et, et, r11		  # preserve the original setting and only turn on motor 0
        stwio et, 0(r10)
		#movui r6, %lo(PERIOD3)
		#movui r7, %hi(PERIOD3)
        call StartTimer1    # polling for PERIOD1 amount of time
        
        br FINISH_TURN
		
MOTOR_TURN_RIGHT:
		movia r11, 0xfffffc00
		ldwio r12, 0(r10)
		and r11, r11, r12		  # get mask for all the bits except for the motor (first 22 bits)
        movia et, 0x000003f3       # motor1 enabled (bit0=0), direction set to forward (bit1=0) 
		or et, et, r11		  # preserve the original setting and only turn on motor 1
        stwio et, 0(r10)
		#movui r6, %lo(PERIOD3)
		#movui r7, %hi(PERIOD3)		
        call StartTimer1 # polling for PERIOD1 amount of time
		
        br FINISH_TURN

# MOTOR_MOVE_FORWARD:
        # movia r11, 0xfffffc00
		# ldwio r12, 0(r10)
		# and r11, r11, r12		  # get mask for all the bits except for the motor (first 22 bits)
        # movia et, 0x000003f0       # motor0 and motor1 enabled (bit0=0), direction set to forward (bit1=0) 
		# or et, et, r11		  # preserve the original setting and turn on motor 0 and motor1
        # stwio et, 0(r10)
        # call StartTimer1 # polling for PERIOD1 amount of time
        # br FINISH_TURN

# InitCounter:
        # # # set r14 as a time counter for backward movement
        # # # i.e. number of times for P.W.M.
        # movi r14, 1

MOTOR_MOVE_BACKWARD:
		# movia r11, 0xfffffc00
		# ldwio r12, 0(r10)
		# and r11, r11, r12		  # get mask for all the bits except for the motor (first 22 bits)
        # movia et, 0x000003fa       # motor0 and motor1 enabled (bit0=0), direction set to backward (bit1=1) 
		# or et, et, r11		  # preserve the original setting and turn on motor 0 and motor1
        # stwio et, 0(r10)
        call I_TURN_ON_MOTOR_BACKWARD
		movui r6, %lo(PERIOD5)
		movui r7, %hi(PERIOD5)
        call StartTimer1	# polling for PERIOD5 amount of time
		call I_TURN_OFF_MOTOR
		movui r6, %lo(PERIOD6)
		movui r7, %hi(PERIOD6)
		call StartTimer1	# polling for PERIOD6 amount of time
		# decrease counter to stop the backward movement
        #subi r14, r14, 1
        #bne r14, r0, MOTOR_MOVE_BACKWARD
        # r13 is 1 then lego car should turn left
		
		movui r6, %lo(PERIOD7)
		movui r7, %hi(PERIOD7)
		bne r13, r0, MOTOR_TURN_LEFT
        br MOTOR_TURN_RIGHT

FINISH_TURN:
		movia r12, 0x000003ff
		or et, r11, r12		# motor0 and motor1 disabled (bit0=1), direction set to backward (bit1=1) 
        stwio et, 0(r10)    # turn the motors off
		stwio et, 12(r10)		# Write to Edge Capture Register (which clears it)
		movui r6, %lo(PERIOD4)
		movui r7, %hi(PERIOD4)
        call StartTimer1    # polling for PERIOD4 amount of time
        br exit

# IDoTimer2:
        # rdctl et, ctl4
        # andi et, et, 0x4 # check if interrupt pending from IRQ2 (ctl4:bit0)
        # beq et, r0, exit # if not timer2, exit the ISR
        # movia et,TIMER2
        # stwio r0,0(et) # ack the interrupt / clear the timer
        # movia r10, ADDR_JP1
        # ldwio r11, 0(r10)
		
		# movia et, 0x08000000	
		# and et, r11, et	# mask to get bit 27
		
        # srli r12, et, 0x1b # check bit 27 sensor0 (forward sensor)
        # bne r12, r0, MOTOR_MOVE_FORWARD
		
		# movia et, 0x10000000
		# and et, r11, et	# mask to get bit 28
		
        # srli r13, et, 0x1c # check bit 28 sensor1 (right sensor)
        # bne r13, r0, MOTOR_TURN_RIGHT
		
		# movia et, 0x20000000
		# and et, r11, et	# mask to get bit 29
		
        # srli r14, et, 0x1d # check bit 29 sensor2 (left sensor)
        # bne r14, r0, MOTOR_TURN_LEFT
        # br MOTOR_MOVE_BACKWARD

exit:
		# restore ra
		ldw et, 4(sp)
		wrctl ctl1, et
		ldw ra, 0(sp)
		addi sp, sp, 8
        subi ea, ea, 4 # adjust return address
        eret

# for interrupt use
StartTimer1:
        movia r8,TIMER1
		stwio r6,8(r8) # low 16bits
        stwio r7,12(r8) # high 16bits
        movui r9,0x4 # start timer, not continued
        stwio r9,4(r8)

Poll1:   
        ldwio r9,0(r8)
        andi r9,r9,0x1 # check if timer has timed out
        beq r9,r0,Poll1 # loop and check again
        stwio r0,0(r8) # clear the timer
        ret # PERIOD seconds has passed
		
I_TURN_ON_MOTOR_BACKWARD:
		ldwio r21, 0(r10)
		movia r22, 0xfffffc00 # get mask for previous state except for the motors
		and r21, r21, r22
		movia r22, 0x0000003fa  # turn on motor0 and motor1 and set its direction to backward
		or r23, r21, r22
		stwio r23, 0(r10)
		ret
		
I_TURN_OFF_MOTOR:
		ldwio r21, 0(r17)
		movia r22, 0xfffffc00 # get mask for previous state except for the motors
		and r21, r21, r22
		movia r22, 0x0000003ff  # turn off motor0 and motor1
		or r23, r21, r22
		stwio r23, 0(r10)
		ret