
.disk [filename="Bubble.d64"] {
    [name="TINY BUBBLE   ", type="prg",  segments="CODE" ]
}
.segment CODE []


.label SCROLY = $d011
.label RASTER = $d012
.label IRQMSK = $d01a
.label CIAICR = $dc0d
.label CI2ICR = $dd0d

*=$02 "Zeropage" virtual
VECTOR1: .word $0000
VECTOR2: .word $0000
VECTOR3: .word $0000
VECTOR4: .word $0000 // reserved as BubbleGrid vector
//VECTOR5: .word $0000 // reserved as score vector
GRID_X: .byte $00
GRID_Y: .byte $00
TMP1: .byte $00
//TMP2: .byte $00
//TMP3: .byte $00
playerBubbleMoving: .byte $00
playerBubbleDX: .word $0000
playerBubbleDY: .word $0000
// variable for drawGrid
charToDraw: .byte $00
bubbleColor: .byte $00
bubbleX: .byte $00
bubbleY: .byte $00

// 8x12 grid for bubble colors
// Value $80 means empty, else value is bubble color [0..7]
bubbleGrid:
    .fill $60, $80
bubbleCount:
    .byte $00
score:
    .fill $05, $00

playerBubbleEnable: .byte $00
playerBubbleColor: .byte $00
playerSightX: .byte $00
playerSightY: .byte $00
playerSightYCorrected: .byte $00
playerBubbleXW: .word $00
playerBubbleYW: .word $00
playerBubblePreviousX: .byte $00
playerBubblePreviousY: .byte $00
playerBubbleGridX: .byte $00
playerBubbleGridY: .byte $00
burstCount: .byte $00
fallenCount: .byte $00
burstFrameCounter: .byte $00
level: .byte $00

// $0100-$011f is Stack
*=$100 "Stack" virtual
    .fill $20, $0

// $0120-$01ec is Code

// 18 bytes of free bytes for variables ($01ed-$01ff)
// Beware, the PRG loader trashes this while loading.
*=$01ed "TrashedVariables" virtual

// Modify the stack so that the load routine branches to our entry point after 
// it has complete its loading.
*=$1f8 "Stack override"   
    .byte <[Entry-1], >[Entry-1]

// $200-$28e is data and code
*=$200 "VariablesHigh"
    // 143 free bytes here
WINDOW_ROW_COLOR_LOOKUP:
    .word $d800+40+28
    .word $d800+2*40+28
    .word $d800+3*40+28    
    .word $d800+4*40+28    
    .word $d800+5*40+28    
    .word $d800+6*40+28    

GRID_ROW_SCREEN_LOOKUP:
.for (var i=1; i<25; i++) {
    .word $0400+i*40+10
}

hiscore:
    .fill $05, $00

InitPlayerSight: {
    // Sprite 1 is HiRes, Sprite 0,2,3 are MultiColor
    ldx #%00001101
    stx $d01c 
    // Sprite enable (sprite 0 is managed elsewhere)
    ldx #$0f
    stx $d015 

    lda #$07  // Sprite 1 color (yellow)
    sta $d028

    lda #$0f
    sta $07f9 // Sprite 1 data pointer

    lda #158
    sta playerSightX
    lda #230
    sta playerSightY

    rts
}



// Vector to the kernal routine which determines which keyboard matrix lookup table 
// to use.
*=$028f "Keyboard setup vector"
    .word $eb48

// $291-$313 Free Data !!!! (131 bytes)
// 131 free bytes here
*=$0291 "VariablesHigh"
    .fill 131,$0

// Vector to IRQ handler
*=$0314 "IRQ vector"   
    .word $ea31

// Vector to RESET handler
*=$0316 "RESET vector"    
    .word $fe66

// Vector to "Kernal Vector"    NMI handler
*=$0318 "NMI vector"       
    .word $fe47

// Kernal indirect vectors
*=$031a "Kernal Vector"   
    .word $f34a // IOPEN (Kernal OPEN routine)
    .word $f291 // ICLOSE (Kernal CLOSE routine)
    .word $f20e // ICHKIN (Kernal CHKIN routine)
    .word $f250 // ICKOUT (Kernal CKOUT routine)
    .word $f333 // ICLRCH (Kernal CLRCHN routine)
    .word $f157 // IBASIN(Kernal CHRIN routine)
    .word $f1ca // IBSOUT (Kernal CHROUT routine)
    .word $f6ed // ISTOP (Kernal STOP routine that check the STOP key)

// 214 free bytes here
*=$032a "VariablesHigh"
SINE_SIGHT_SCREEN_LOOKUP: {
.fill 32,round(26*sin(toRadians(i*192/32)))
}

highlightBursted: .byte $00

CheckPlayerMouve: {

    lda $DC00 // CIA1 port 1 (Joystick 2 read)
    tax
    and #$04
    bne right
left:
    lda playerSightX
    cmp #102
    bcc end
    dec playerSightX
//    dec playerSightX
    jmp end
right:
    txa
    and #$08
    bne end
    lda playerSightX
    cmp #220
    bcs end
    inc playerSightX
//    inc playerSightX
    jmp end
end:
    jsr updateSight
    rts
}

// Autostarting PRG code under $1000
// 3767 bytes free for code
// 254 zero page bytes free for variables
// 18 bytes at $1ed for variables
*=$120 "Code"
Entry: {
    // reduce stack to use only 32 bytes ($100-$11f)
    ldx #$1f 
    txs   

    sei

    // Ask VIC2 to use character data at $0800 (2048)
    // and default VideoMatrix at $0400 (1024)
    lda #%00010010
    sta $d018

    // Enable multicolor mode
    lda $d016
    ora #%00010000
    sta $d016

    lda #$00
    // Set Border Color = black
    sta $d020
    // Set BGColor1 = black
    sta $d021
    sta burstCount

    // Set BGColor0 = grey
    lda #11
    sta $d022

    // Set BGColor2 = white
    lda #01
    sta $d023

    // Fill Color RAM with multicolor RED 
    ldx #$00
    lda #$0a
!:
    sta $d800,x
    sta $d800+$100,x
    sta $d800+$200,x
    sta $d800+$300,x
    dex
    bne !-    

    // VECTOR4 points to bubble grid (colors)
    lda #<bubbleGrid
    sta VECTOR4
    lda #>bubbleGrid
    sta VECTOR4+1

    jsr InitInterrupt
    jsr InitSid
    jsr InitScore
    jsr InitWindow
    jsr InitSupport
    jsr InitPlayerSight
    jsr InitPlayerBubble

    jsr resetLevel
    lda level
    jsr LoadLevel

    jsr DrawGrid2

    cli
    ldx #<InitPlayerBubble-1

    ldx #$ff
    txs
    jmp mainLoop
}

InitInterrupt: {

    // Start your code HERE (205 bytes up to $1ec)
    // Changer IRQ handler
    lda #<IRQHandler
    sta $0314
    lda #>IRQHandler
    sta $0315

    // Disable all CIA1 & CIA2 interrupts
    lda #%01111111
    sta CIAICR
    sta CI2ICR
    // Read CIA interrupt control register to acknowledge pending IRQ
    lda CIAICR
    lda CI2ICR

    // Enable raster IRQ
    lda IRQMSK
    ora #$01
    sta IRQMSK

    // Clear MSB of raster compare
    lda SCROLY
    and #$7f
    sta SCROLY

    // Set IRQ to occure on raster line 18
    lda #252
    sta RASTER

    rts
}

InitWindow: {

    ldx #$00

    loop: {
       ldy #10
       lda #$0b // Blue char color (multicolor mode)
    innerLoop:
       sta $d800+40+28,y
       dey
       bpl innerLoop

    modifyScreenPointer:
       clc
       lda innerLoop+1
       adc #40
       sta innerLoop+1
       bcc !+
       inc innerLoop+2
    !:
       inx
       cpx #3
       beq modifyScreenPointer
       cpx #4
       beq modifyScreenPointer
       cpx #08
       bne loop
    }

    jsr drawScore
    
    rts
}


*=$380 "bubbleSprite"
spriteBubble:
    .byte $05,$80,$00,$16,$a0,$00,$19,$a0
    .byte $00,$66,$a8,$00,$66,$a8,$00,$6a
    .byte $a4,$00,$6a,$a4,$00,$6a,$a4,$00
    .byte $6a,$a4,$00,$aa,$a8,$00,$2a,$a0
    .byte $00,$2a,$90,$00,$09,$40,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$83

*=$3c0 "sightSprite"
spriteSight:
    .byte $00,$40,$00,$00,$00,$00,$00,$40
    .byte $00,$00,$40,$00,$00,$40,$00,$00
    .byte $00,$00,$00,$e0,$00,$01,$10,$00
    .byte $02,$08,$00,$ba,$0b,$a0,$02,$08
    .byte $00,$01,$10,$00,$00,$e0,$00,$00
    .byte $00,$00,$00,$40,$00,$00,$40,$00
    .byte $00,$40,$00,$00,$00,$00,$00,$40
    .byte $00,$00,$40,$00,$00,$00,$00,$07

*=$400 "VideoMatrix"
// $400-$7e8 is the VideoMatrix
.import binary "assets/map.bin"

*=$7F8 "SpritesPointers" virtual

// $800-? is the custom charset
*=$800 "Charset"
.import binary "assets/charset.bin"

*=$980 "supportSpriteLeft"
spriteSupportLeft:
.byte $00,$00,$d7,$00,$03,$6a,$00,$01
.byte $aa,$00,$06,$af,$00,$3a,$bf,$00
.byte $1a,$c0,$00,$eb,$00,$00,$6b,$00
.byte $00,$a8,$00,$03,$ac,$00,$01,$ac
.byte $00,$02,$a0,$00,$02,$ac,$00,$06
.byte $a0,$00,$06,$ac,$00,$3a,$a0,$00
.byte $1a,$ac,$00,$1a,$a8,$00,$ea,$a8
.byte $00,$6a,$aa,$00,$6a,$aa,$c0,$82

*=$9C0 "supportRightSprite"
spriteSupportRight:
.byte $70,$00,$00,$ac,$00,$00,$a8,$00
.byte $00,$ab,$00,$00,$fa,$00,$00,$3a
.byte $80,$00,$0e,$20,$00,$0e,$80,$00
.byte $02,$a0,$00,$02,$88,$00,$03,$a0
.byte $00,$00,$a8,$00,$03,$a0,$00,$00
.byte $a8,$00,$03,$a2,$00,$00,$a8,$00
.byte $03,$a2,$00,$02,$a8,$80,$03,$aa
.byte $00,$0e,$a8,$80,$3a,$aa,$20,$82

mainLoop: {
    jmp * 
}

InitPlayerBubble: {
    ldx #$0
    stx playerBubbleMoving
    inx
    stx $d025 // Sprite multicolor 0
    stx playerBubbleEnable

    ldx #$0e
    stx $07f8 // Sprite 0 data pointer = $e

    ldx #$0b
    stx $d026 // Sprite multicolor 1 = $f

    lda #$0f
    sta $d015 // Sprite enable 0-3

    jsr computePlayerColor
    sta playerBubbleColor // maybe we could directly use sprite color register
    sta $d027

    lda #161
    sta playerBubbleXW+1
    sta $d000

    lda #236
    sta playerBubbleYW+1
    sta $d001

    rts
}

*=* "Code"
InitSupport: {

    lda #$02 // Sprite 2,3 color (yellow)
    sta $d029
    sta $d02a

    ldy #$26
    sty $07fa // Sprite 2 data pointer
    iny
    sty $07fb // Sprite 3 data pointer

    // Sprites X
    lda #146
    sta $d004
    lda #146+24
    sta $d006

    // Sprites Y
    lda #229
    sta $d005
    sta $d007

    rts
}

IRQHandler: {
    // Acknowledge interrupts
    inc $d019
//    inc $d401

    // change border color
//    lda #$1
//    sta $d020

    lda burstCount
    cmp #$03
    bcc !+
    // If at least 3 bubble to burst
    jsr handleBurst
    bvc end
!:
    // ensure that burst bubbles are reset (if less than 3 encountered)
    lda burstCount
    beq !+
    jsr resetBubblesStates
!:
    jsr CheckPlayerMouve
    jsr MovePlayerBubble

    // change border color
//    dec $d020

    // Restore registers
end:
    pla 
    tay
    pla
    tax 
    pla 
    rti 
}

handleBurst: {
    lda burstFrameCounter
    bne !+
    sta highlightBursted // don't display highlighted balls anymore
    jsr clearBurstBubbles
    jsr clearOrpheanBubbles
    jsr playExplosionSound
    jsr resetBubblesStates
    jsr updateScore
    jsr DrawGrid2

    lda #$0
    sta burstCount
    jsr stopSound

    // If no more bubble in grid, load next level
    lda bubbleCount
    bne end
    jsr playBellSound
    jsr incrementLevel
    jsr LoadLevel
    jsr DrawGrid2
    rts
!:
    and #$01
    sta highlightBursted
    jsr DrawGrid2
    dec burstFrameCounter
end:
    rts
}

clearBurstBubbles: {
    ldy #80
loop:
    lda (VECTOR4),y
    and #$10
    beq !+
    lda #$80
    sta (VECTOR4),y
!:
    dey
    bpl loop
    rts
}

updateScore: {
    // update score (+5) per burst bubble (+10) per fallen bubble
    lda fallenCount
    asl
    clc
    adc burstCount
    asl
    asl
    adc fallenCount
    adc fallenCount
    adc burstCount
    asl

    tax
!:
    txa
    pha
    jsr addScore1
    pla 
    tax
    dex
    bne !-

    jsr drawScore

    rts
}

playPocSound: {

    // Attack/decay (Voice1)
    lda #$33
    sta $d405

    // Sustain/release (Voice1)
    lda #$f5
    sta $d406

    // Lo/Hi frequency (Voice1)
    lda #0
    sta $d400
    jsr loadRandom
    clc
    ora #$40
    sta $d401

    // Triangle waveform and gate on (Voice 1)
    lda #%10000001
    sta $d404

    rts
}

playExplosionSound: {

    // Attack/decay (Voice1)
    lda #$0b
    sta $d405+7

    // Sustain/release (Voice1)
    lda #$ba
    sta $d406+7

    // Lo/Hi frequency (Voice1)
    lda #$ff
    sta $d400+7
    lda #$ff
    sta $d401+7

    // Noise waveform and gate on (Voice 1)
    lda #%10000001
    sta $d404+7

    rts
}

playBellSound: {

    // Attack/decay (Voice1)
    lda #$0c
    sta $d405
    // Sustain/release (Voice1)
    sta $d406


    // Hi frequency (Voice1)
    lda #67
    sta $d401
    sta $d401+14

    // Triable waveform, ring modulation, gate on
    lda #%00010101
    sta $d404

    ldx #$40
!:
    stx $d401
    inx
    bne !-

    lda #%00010100
    sta $d404

    rts
}

stopSound: {
    // Gate off (Voice 1)
    lda #%10000000
    sta $d404
    sta $d404+7

    rts
}

resetBubblesStates: {
    ldy #80
loop:
    lda (VECTOR4),y
    // clear burst and orphean flags
    and #$cf
    sta (VECTOR4),y
    dey

    bpl loop

    rts
}

clearOrpheanBubbles: {
    ldy #$0
    sty bubbleY
    sty fallenCount
    ldx #07
    stx bubbleX
!:
    lda bubbleX
    pha 
    lda bubbleY
    pha 
    
    jsr recurseAttached

    pla
    sta bubbleY
    pla 
    lda bubbleX

    dec bubbleX
    bpl !-

    ldy #80
loop:
    lda (VECTOR4),y
    cmp #$80
    beq !+
    and #$20
    bne !+
    inc fallenCount
    lda #$80
    sta (VECTOR4),y
!:
    dey
    bpl loop
 
    rts    
}

*=* "AAA"
recurseAttached: {

    lda #<recurseCore
    sta recurseFunction.functionVector
    lda #>recurseCore
    sta recurseFunction.functionVector+1

recurseCore:
    jsr gridXYtoIndex
    lda (VECTOR4),y
    tax
    and #$80
    beq !+
    rts
!:
    txa
    and #$20
    beq !+
    rts
!:
    txa
    ora #$20
    sta (VECTOR4),y

    jsr recurseNeighbors
    rts

}



DrawGrid2: {
    lda #19
    sta GRID_Y
    lda #$0f
    sta GRID_X

    // reset colors counter
    lda #$0
    sta bubbleCount

    // VECTOR1 points to screen address lookup for all 25 rows
    lda #<GRID_ROW_SCREEN_LOOKUP
    sta VECTOR1
    lda #>GRID_ROW_SCREEN_LOOKUP
    sta VECTOR1+1

    // load screen address for GridY (0=first row)
    loop: {
        // let Y=2*GRID_Y (lookup table stores 16bits address words)
        lda GRID_Y
        asl
        tay
        // Let Vector2 points the start address of VideoMatrix for (0, Grid_Y) in (16*20 char grid coordinates system)
        // Let Vector3 points the start address of ColorRAM for (0, Grid_Y) in (16*20 char grid coordinates system)
        lda (VECTOR1),y
        sta VECTOR2
        sta VECTOR3
        iny
        lda (VECTOR1),y
        sta VECTOR2+1
        adc #$d4
        sta VECTOR3+1

    rowLoop:
        // are we on en even or odd 2x2 Grid row ? 
        lda GRID_Y
        lsr 
        sta bubbleY
        and #$01
        bne oddBubbleRow

    evenBubbleRow: {
        // Ok, we are on en even 2x2 Grid row.
        // Save bubbleX coordinate (grid / 2)
        lda GRID_X
        tax
        bpl oddBubbleRow.computeBubbleCharToDraw
    }

    oddBubbleRow: {
        lda GRID_X
        beq empty

        cmp #$0f
        beq empty

        // Save bubbleX coordinate (grid+1 / 2)
        eor #$01
        tax   
        clc
        eor #$01
        adc #$01

    computeBubbleCharToDraw:
        lsr 
        sta bubbleX        
        lda GRID_Y
        and #$01
        asl
        sta TMP1
        txa
        and #$01
        clc
        adc #$0a   
        adc TMP1
        sta charToDraw

        jmp nextChar

    empty:
        lda #$0e
        sta charToDraw
        jmp nextChar
    }

    nextChar:
        // load into <Y> the color of bubble at bubbleX, bubbleY
        jsr gridXYtoIndex

        lda (VECTOR4),y // load bubble color
        ldy GRID_X
        cmp #$80
        beq emptyChar // skip ColorRAM write, and draw empty char

        ldx highlightBursted
        beq !+
        tax
        and #$10
        beq notBursted
        lda #$01
        bvc !+
    notBursted:
        txa

        // set color ram according to bubble color
    !:
        ora #$08 
        sta (VECTOR3),y
        lda charToDraw
        bne drawChar

    emptyChar:
        lda #$0e
    drawChar:
        sta (VECTOR2),y
        cmp #$0e
        beq nextCharInRow
        inc bubbleCount

    nextCharInRow:
        dec GRID_X
        bmi !+
        jmp rowLoop
    }   

!:
//    lda bubbleCount
//    .break

    lda #$0f
    sta GRID_X
    dec GRID_Y
    bmi !+

    jmp loop
!:
    rts
}   

updateSight: {

    lda #<SINE_SIGHT_SCREEN_LOOKUP
    sta VECTOR1
    lda #>SINE_SIGHT_SCREEN_LOOKUP
    sta VECTOR1+1

    lda playerSightX
    sta $d002

    // Compute (Sight.x-100) / 4. It serves as Index in the sine table
    sec
    sbc #100
    lsr
    lsr
    tay 

    lda playerSightY
    sec
    sbc (VECTOR1),y
    sta playerSightYCorrected
    sta $d003

    // fire button check should be done in CheckPlayerMove (but no more room for code there !)
    lda $dc00
    and #$10
    bne end
    // fire pressed, change player bubble state and compute its direction
    lda playerBubbleMoving
    bne end
    inc playerBubbleMoving

    // Compute DX (DX=Sight.X+3-PlayerBubble.X) 
    // (3 is to vertically align sprites X coordinates)
    lda #$0
    sta playerBubbleDX+1
    lda playerSightX
    clc
    adc #$03
    sec
    sbc playerBubbleXW+1
    sta playerBubbleDX
    bpl !+
    dec playerBubbleDX+1

!:
    // DX is encoded on a word for better accuracy (DX.w = DX.b << 5)
    ldx #$5
!shift:
    asl playerBubbleDX
    rol playerBubbleDX+1
    dex
    bne !shift-

    // Compute DY (DY=Sight.Y-PlayerBubble.Y)
    lda #$0
    sta playerBubbleDY+1
    ldx playerSightYCorrected
    inx
    inx
    inx
    txa
    sec
    sbc playerBubbleYW+1
    sta playerBubbleDY
    bpl !+
    dec playerBubbleDY+1
!:
    // DY is encoded on a word for better accuracy (DY.w = DY.b << 5)
    ldx #$5
!shift:
    asl playerBubbleDY
    rol playerBubbleDY+1
    dex
    bne !shift-

    // initialize double precision bubble coordinates
    lda #$00
    sta playerBubbleXW
    sta playerBubbleYW

end:
    rts
}

AppendPlayerBubble: {
    jsr playPocSound
    // Hide player sprite
    lda #%00001110
    sta $d015
    // If the collision occured while player GridY >= 10, then he has lost
    lda playerBubbleGridY
    cmp #10
    bcc notLostGame
    // In this case, reload level 1
    jsr InitScore
    jsr resetLevel
    jsr LoadLevel
    jmp end
notLostGame:
    // Write the player color into bubble grid
    lda playerBubbleGridX
    sta bubbleX
    lda playerBubbleGridY
    sta bubbleY
    jsr gridXYtoIndex
    lda playerBubbleColor
    sta (VECTOR4),y
    lda #$0
    sta burstCount
    ldx #$0f
    stx burstFrameCounter
    jsr recurseBurst
end:
    // Redraw grid
    jsr DrawGrid2
    jsr stopSound
    rts
}


recurseFunction: {
    tsx
    cpx #$06
    bcs !+
    rts // not enough space in stack... stop recurce !

!:
    jmp (functionVector)
functionVector:
    .word $00
}

// Define macro
.macro pushBubbleXY() {
    lda bubbleY
    pha 
    lda bubbleX
    pha
}

.macro pullBubbleXY() {
    pla 
    sta bubbleX
    pla
    sta bubbleY
}

recurseNeighbors: {

    checkUpper:
        lda bubbleY
        cmp #$0
        beq checkLeft

        pushBubbleXY()
        dec bubbleY
        jsr recurseFunction
        pullBubbleXY()

    checkUpperLeft:
        lda bubbleY
        and #$01
        beq checkUpperRight

        pushBubbleXY()
        dec bubbleY
        dec bubbleX
        jsr recurseFunction
        pullBubbleXY()
        jmp checkLeft

    checkUpperRight:
        lda bubbleX
        cmp #$07
        beq checkLeft

        pushBubbleXY()
        dec bubbleY
        inc bubbleX
        jsr recurseFunction
        pullBubbleXY()

    checkLeft:
        lda bubbleX
        cmp #$0
        beq checkRight

        pushBubbleXY()
        dec bubbleX
        jsr recurseFunction
        pullBubbleXY()

    checkRight:
        cmp #$07
        beq checkLower

        pushBubbleXY()
        inc bubbleX
        jsr recurseFunction
        pullBubbleXY()

    checkLower:
        pushBubbleXY()
        inc bubbleY
        jsr recurseFunction
        pullBubbleXY()

    checkLowerLeft:
        // Check only if we are on an odd grid row
        lda bubbleY
        and #$01
        beq checkLowerRight
        lda bubbleX
        beq checkLowerRight

        pushBubbleXY()
        dec bubbleX
        inc bubbleY
        jsr recurseFunction
        pullBubbleXY()
        jmp end

    checkLowerRight:
        lda bubbleX
        cmp #$07
        beq end

        pushBubbleXY()
        inc bubbleY
        inc bubbleX
        jsr recurseFunction
        pullBubbleXY()


    end:
        rts
}

recurseBurst: {

    lda #<recurseCore
    sta recurseFunction.functionVector
    lda #>recurseCore
    sta recurseFunction.functionVector+1

recurseCore:
    jsr gridXYtoIndex
    lda (VECTOR4),y
    tax
    // empty grid location ? then exit
    cmp #$80
    bne !+
    rts
    // already visited ? then exit
!:
    and #$10
    beq !+
    rts
!:
    // bubble color does not match ? then exit
    cpx playerBubbleColor
    beq !+
    rts 
!:
    // Ok, we have found a matching bubble at BubbleX, BubbleY
    // Increase burstCounter
    inc burstCount
    // Mark bubble and recurse
    txa
    ora #$10
    sta (VECTOR4),y

    jsr recurseNeighbors
    rts
}

MovePlayerBubble: {
    // If player bubble is not moving, exit
    lda playerBubbleMoving
    bne !+
    rts
!:
    // Read hardware collision register
    
    lda $d01f
    and #$01
    beq !+
    jsr AppendPlayerBubble
    jsr InitPlayerBubble
    rts
!:
    
    // Let playerBubblePreviousX = playerBubbleXW+1
    // and playerBubbleXW.w += playerBubbleDX.w
    lda playerBubbleXW
    clc
    adc playerBubbleDX
    sta playerBubbleXW
    lda playerBubbleXW+1
    sta playerBubblePreviousX
    adc playerBubbleDX+1
    sta playerBubbleXW+1

    // Let playerBubblePreviousY = playerBubbleYW+1
    // and playerBubbleYW.w += playerBubbleDY.w
    lda playerBubbleYW
    clc
    adc playerBubbleDY
    sta playerBubbleYW
    lda playerBubbleYW+1
    sta playerBubblePreviousY
    adc playerBubbleDY+1
    sta playerBubbleYW+1

    // Has bubble hit the right border ?
    lda playerBubbleXW+1
    cmp #220
    bcc checkLeftBorder
    // If so, set BubbleX and reverse DX
    lda #220
    bne reverseDirection

checkLeftBorder:
    // Has bubble hit the left border ?
    lda playerBubbleXW+1
    cmp #105
    bcs !+
    // If so, set BubbleX and reverse DX
    lda #105
reverseDirection:
    sta playerBubbleXW+1
    lda #$0
    sta playerBubbleXW
    lda playerBubbleDX
    eor #$ff
    sta playerBubbleDX
    lda playerBubbleDX+1
    eor #$ff
    sta playerBubbleDX+1

!:
    // compute playerBubbleGridX and playerBubbleGridY
    lda playerBubbleYW+1 //playerBubblePreviousY
    clc
    sbc #50-2
    lsr
    lsr
    lsr
    lsr
    sta playerBubbleGridY
    and #$01
    bne oddLine

    // bubble on even grid line
evenLine:
    lda playerBubbleXW+1 //playerBubblePreviousX
    clc
    sbc #106-8
    lsr
    lsr
    lsr
    lsr
    // If X<0, then X=0
    cmp #$0
    bpl !+
    lda #$0
!:
    // If X>7, then X=7
    cmp #$8
    bcc !+
    lda #$7
!:
    sta playerBubbleGridX
    jmp !+

oddLine:
    lda playerBubbleXW+1 // playerBubblePreviousX
    clc
    sbc #106-17
    lsr
    lsr
    lsr
    lsr
/*    bne !+
    clc
    adc #$01
!:*/
    // If X<1, then X=1
    cmp #$1
    bpl !+
    lda #$1
!:
    // If X>7, then X=7
    cmp #$8
    bcc !+
    lda #$7
!:
    sta playerBubbleGridX
!:
//    jsr computeNeighbors

    // Has bubble hit the top border ?
/*    lda playerBubbleYW+1
    cmp #$40
    bcs updatePlayerSprite
    jsr InitPlayerBubble
    jsr DrawGrid2 // remove me ! */

updatePlayerSprite:
    lda playerBubbleXW+1
    sta $d000
    lda playerBubbleYW+1
    sta $d001

 /*   lda playerBubbleGridX
    sta bubbleX
    lda playerBubbleGridY
    sta bubbleY
    jsr gridXYtoIndex
    lda #$01
    sta (VECTOR4),y
    jsr DrawGrid2*/

end:
    rts
}

/**
 * @param bubbleY the grid Y coordinate [0..9]
 * @param bubbleX the grid X coordinate [0..7]
 * @return the grid index of bubble in <Y> [0..79]
 */
gridXYtoIndex: {
    lda bubbleY
    asl
    asl
    asl
    ora bubbleX
    tay
    rts
}

addScore1: {
    ldy #$4
    clc

    lda score,y
    adc #$1
    bvc !+
loop:
    lda score,y
    adc #$0
!:
    sta score,y
    clc
    cmp #$0a
    bne !+
    lda #$0
    sta score,y
    sec
!:
    dey
    bpl loop

    jsr UpdateHighscore

    rts
}

incrementLevel: {
    inc level
    ldx #10
!:  
    inc $400+40+28,x
    lda $400+40+28,x
    cmp #10
    bne !+
    lda #0
    sta $400+40+28,x
    dex 
    bpl !-
!:
    rts 
}

resetLevel: {
    lda #$0
    sta level
    ldx #2
    lda #$0
!:
    sta $400+40+36,x
    dex
    bpl !-
    jsr incrementLevel
}

InitScore: {

    ldy #$04
!:
    lda #$00
    sta score,y
    dey
    bpl !-

    jsr drawScore

    rts
}

drawScore: {

    ldy #$04
!:
    lda score,y
    sta $0400+120+34,y
    lda hiscore,y
    sta $0400+120+5*40+34,y
    dey
    bpl !-

end:
    rts
}

UpdateHighscore: {
    // for each digit of score, compare with match digit of highscore
    ldx #$0
!:
    lda score,x
    cmp hiscore,x
    // if current score digit is lower, then exit
    bmi end     // would be better to use BCC (currentCharscore are unsigned !)
    // if current score digit is higher, then replace highscore
    bne update
    // else if digit are equal, check the next digit, until all 6 are processed
    inx
    cpx #$05
    bne !-
end:
    rts
    
update:
    // replace highscore directly in screen RAM 
    // (X still contains the first digit index to replace)
    lda score,x
    sta hiscore,x
    inx
    cpx #$06
    bne update
    rts
}

/**
 * @param <A> contains the index level 
 */
LoadLevel: {
    lda level
!:
    cmp #$04
    bcc !+
    sec
    sbc #$03
    jmp !-

!:
    tax
    lda #<Level1
    sta VECTOR1
    lda #>Level1
    sta VECTOR1+1

    clc
!:
    dex
    beq decrunchGrid
    lda VECTOR1
    adc #24
    sta VECTOR1
    bcc noCarry
    inc VECTOR1+1
noCarry:
    jmp !-

decrunchGrid:
    ldx #96
!loop:
    txa
    lsr
    tay
    lda (VECTOR1),y
    tay
    txa
    and #$01
    beq odd
even:
    tya
    jmp !+
odd:
    tya
    lsr
    lsr
    lsr
    lsr
!:
    and #$0f
    cmp #$08
    bcc next
    lda #$80
    jmp !+
next:
    and #$07
!:
    cpx #48
    bcc !+
    lda #$80
!:
    stx TMP1
    ldy TMP1
    sta (VECTOR4),y
    dex
    bpl !loop-

    rts
}

/**
 * @return A random color in <A>
 */
computePlayerColor: {
   
!:    
    jsr loadRandom
    and #$07
    cmp #$01
    beq !-

    rts
}

InitSid: {
    lda #$0
    ldy #24
!:
    sta $d400,y
    dey
    bpl !-

    lda #$ff // maximum frequency value
    sta $d40e // voice 3 frequency low byte
    sta $d40f // voice 3 frequency high byte
    lda #$80  //noise waveform, gate bit off
    sta $d412 //  voice 3 control register

    // Set volume
    lda #15
    sta $d418

    rts
}

loadRandom: {
    lda $d41b
    rts
}

*=$0fb8 "Levels"
Level1: 
    .byte $66,$44,$22,$33
    .byte $F6,$64,$42,$23
    .byte $22,$33,$66,$44
    .byte $F2,$33,$66,$44
    .byte $FF,$FF,$FF,$FF
    .byte $FF,$FF,$FF,$FF

/*    .byte $44,$44,$44,$4f
    .byte $ff,$ff,$ff,$f4
    .byte $f4,$44,$44,$4f
    .byte $44,$ff,$ff,$ff
    .byte $f4,$44,$44,$44
    .byte $66,$66,$66,$66*/
/*
    .byte $33,$33,$33,$33
    .byte $FF,$FF,$FF,$FF
    .byte $FF,$FF,$FF,$FF
    .byte $FF,$FF,$FF,$FF
    .byte $FF,$FF,$FF,$FF
    .byte $FF,$FF,$FF,$FF*/

Level2: 
    .byte $F4,$44,$66,$6F
    .byte $F4,$FF,$FF,$F6
    .byte $F4,$FF,$FF,$6F
    .byte $F4,$23,$52,$36
    .byte $F2,$52,$35,$2F
    .byte $FF,$FF,$FF,$FF

Level3: 
    .byte $F7,$7F,$F5,$5F
    .byte $F5,$F3,$F2,$F4
    .byte $25,$F4,$7F,$43
    .byte $F2,$FF,$5F,$F3
    .byte $52,$FF,$FF,$34
    .byte $F5,$FF,$FF,$F4
/*
    .byte $F5,$32,$46,$7F
    .byte $F5,$FF,$FF,$FF
    .byte $F2,$34,$76,$4F
    .byte $FF,$FF,$FF,$F5
    .byte $F3,$FF,$FF,$5F
    .byte $FF,$23,$47,$6F*/

/**
author:
    .text "written in 2021 by s.mametz"
*/
/*
    .byte $FF,$77,$77,$FF
    .byte $FF,$FF,$5F,$FF
    .byte $FF,$F5,$2F,$FF
    .byte $FF,$FF,$2F,$FF
    .byte $FF,$F2,$5F,$FF
    .byte $FF,$FF,$5F,$FF
*/

