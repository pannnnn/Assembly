#this version has two interrupt one for timer and one for sensor

.equ ADDR_PUSHBUTTONS, 0xFF200050 # Address Pushbuttons
.equ ADDR_JP1, 0xFF200060   # Address GPIO JP1
.equ ADDR_JP1_TIMER2_IRQ, 0x0804      # IRQ line for GPIO JP1 (IRQ11) and TIMER2 (IRQ2) 
.equ TIMER1, 0xFF202000 # Address TIMER1
.equ TIMER2, 0xFF202020   # Address TIMER2
.equ PERIOD1, 10000000 # time period for polling
.equ PERIOD2, 100000000 # time period

.text

.global main

main:
start:
        call InitTimer1
        call InitTimer2
        call InitMotors
        movia  r8, ADDR_JP1_TIMER2_IRQ    # enable interrupt for GPIO JP1 (IRQ11) and TIMER2 (IRQ2)
        wrctl  ctl3, r8
        movia  r8, 1
        wrctl  ctl0, r8            # enable global interrupts
LOOP:
        br LOOP

InitTimer1:
        movia r8,TIMER1
        movui r9,%lo(PERIOD1)
        stwio r9,8(r8) # low 16bits
        movui r9,%hi(PERIOD1)
        stwio r9,12(r8) # high 16bits
        stwio r0,0(r8) # clear the timer
        ret

InitTimer2:
        movia r8,TIMER2
        movui r9,%lo(PERIOD2)
        stwio r9,8(r8) # low 16bits
        movui r9,%hi(PERIOD2)
        stwio r9,12(r8) # high 16bits
        stwio r0,0(r8) # clear the timer
        movi r10,0b111 #start timer, continuous, interrupt enabled
        stwio r10,4(r8) #enable timer interrupt
        ret

InitMotors:
        movia r8, ADDR_JP1
        movia r9, 0x07f557ff       # set direction for motors to all output 
        stwio r9, 4(r8)
        # load sensor0 threshold value 5 and enable sensor0
        movia  r9,  0xfabffbff       # set motors off enable threshold load sensor 0
        stwio  r9,  0(r8)            # store value into threshold register
        # load sensor1 threshold value 5 and enable sensor1
        movia  r9,  0xfabfefff       # set motors off enable threshold load sensor 1
        stwio  r9,  0(r8)            # store value into threshold register
        # load sensor2 threshold value 5 and enable sensor2
        movia  r9,  0xfabfbfff       # set motors off enable threshold load sensor 2
        stwio  r9,  0(r8)            # store value into threshold register
        # disable threshold register and enable state mode
        movia  r9,  0xfadffff0      # keep threshold value same in case update occurs before state mode is enabled, and enable motor 0 and motor 1 to be forward
        stwio  r9,  0(r8)
        # enable interrupts
        movia  r9, 0x08000000       # enable interrupts on sensor0
        stwio  r9, 8(r8)
        ret

.section .exceptions, "ax"
IHANDLER:
        # check to see if sensor0 interrupt happened    
        rdctl et, ctl4
        andi et, et, 0x0800 # check if interrupt pending from IRQ11 (ctl4:bit1)
        beq et, r0, IDoTimer2 # if not sensor0, try timer

ChangeDir:
        movia r10, ADDR_JP1
        ldwio r11, 12(r10)
		
Sensor0_Inter:
        movia r12, 0x08000000	# check if interrupt caused by sensor 0 
        and r13, r11, r12
        srli r13, r13, 0x1b
        bne r13, r0, MOTOR_TURN
        br exit
		
#Sensor1_Inter:		
#	movia r12, 0x10000000	# check if interrupt caused by sensor 1
#       and r13, r11, r12
#       srli r13, r13, 0x1c
#       bne r13, r0, MOTOR_TURN_LEFT
#	br exit

MOTOR_TURN: #Decide which way to turn
        ldwio et, 0(r10)
		movia r11, 0x10000000
		and r11, r11, et
        srli r12, r11, 0x1c # check bit 28 sensor1 (right sensor)
        bne r12, r0, MOTOR_TURN_RIGHT
		movia r11, 0x20000000
		and r11, r11, et
        srli r12, r11, 0x1d # check bit 29 sensor2 (left sensor)
        bne r12, r0, MOTOR_TURN_LEFT
        br MOTOR_MOVE_BACKWARD

MOTOR_TURN_LEFT:
		movia r11, 0xfffffc00
		ldwio r12, 0(r10)
		and r11, r11, r12		  # get mask for all the bits except for the motor (first 22 bits)
        movia et, 0x000003fc       # motor1 enabled (bit0=0), direction set to forward (bit1=0) 
		or et, et, r11		  # preserve the original setting and only turn on motor 0
        stwio et, 0(r10)
        call StartTimer1 # polling for PERIOD1 amount of time
        br FINISH_TURN
		
MOTOR_TURN_RIGHT:
		movia r11, 0xfffffc00
		ldwio r12, 0(r10)
		and r11, r11, r12		  # get mask for all the bits except for the motor (first 22 bits)
        movia et, 0x000003f3       # motor1 enabled (bit0=0), direction set to forward (bit1=0) 
		or et, et, r11		  # preserve the original setting and only turn on motor 1
        stwio et, 0(r10)
        call StartTimer1 # polling for PERIOD1 amount of time
        br FINISH_TURN

MOTOR_MOVE_FORWARD:
        movia r11, 0xfffffc00
		ldwio r12, 0(r10)
		and r11, r11, r12		  # get mask for all the bits except for the motor (first 22 bits)
        movia et, 0x000003f0       # motor 0 and motor1 enabled (bit0=0), direction set to forward (bit1=0) 
		or et, et, r11		  # preserve the original setting and turn on motor 0 and motor1
        stwio et, 0(r10)
        call StartTimer1 # polling for PERIOD1 amount of time
        br FINISH_TURN

MOTOR_MOVE_BACKWARD:
		movia r11, 0xfffffc00
		ldwio r12, 0(r10)
		and r11, r11, r12		  # get mask for all the bits except for the moto	r (first 22 bits)
        movia et, 0x000003fa       # motor 0 and motor1 enabled (bit0=0), direction set to backward (bit1=1) 
		or et, et, r11		  # preserve the original setting and turn on motor 0 and motor1
        stwio et, 0(r10)
        call StartTimer1 # polling for PERIOD1 amount of time
        br FINISH_TURN

FINISH_TURN:
		movia r12, 0x000003ff
		or et, r11, r12		# motor0 and motor1 disabled (bit0=1), direction set to backward (bit1=1) 
        stwio et, 0(r10)
		stwio et, 12(r10)		# Write to Edge Capture Register (which clears it)
        br exit

IDoTimer2:
        rdctl et, ctl4
        andi et, et, 0x4 # check if interrupt pending from IRQ2 (ctl4:bit0)
        beq et, r0, exit # if not timer2, exit the ISR
        movia et,TIMER2
        stwio r0,0(et) # ack the interrupt / clear the timer
        movia r10, ADDR_JP1
        ldwio r11, 0(r10)
		
		movia et, 0x08000000	
		and et, r11, et	# mask to get bit 27
		
        srli r12, et, 0x1b # check bit 27 sensor0 (forward sensor)
        bne r12, r0, MOTOR_MOVE_FORWARD
		
		movia et, 0x10000000
		and et, r11, et	# mask to get bit 28
		
        srli r13, et, 0x1c # check bit 28 sensor1 (right sensor)
        bne r13, r0, MOTOR_TURN_RIGHT
		
		movia et, 0x20000000
		and et, r11, et	# mask to get bit 29
		
        srli r14, et, 0x1d # check bit 29 sensor2 (left sensor)
        bne r14, r0, MOTOR_TURN_LEFT
        br MOTOR_MOVE_BACKWARD

exit:
        subi ea,ea,4 # adjust return address
        eret

StartTimer1:
        movia r8,TIMER1
        movui r9,0x4 # start timer, not continued
        stwio r9,4(r8)

Poll:   
        ldwio r9,0(r8)
        andi r9,r9,0x1 # check if timer has timed out
        beq r9,r0,Poll # loop and check again
        stwio r0,0(r8) # clear the timer
        ret # PERIOD1 seconds has passed