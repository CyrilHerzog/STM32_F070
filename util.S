/* 
-----------------------------------------------------------------------------------------
Datei   : util.s
Autor   : Herzog Cyril
Version : 1.0
Datum   : 05.10.2023
-----------------------------------------------------------------------------------------

Beschreibung:
    Bibliothek für nützliche Funktionen 
        - WAIT        => Programmbearbeitung verzögern
        - MEMCLR      => Datenbereich löschen
        - MEMCPY      => Datenbereich umkopieren
        - NEG_FLAG    => Negative Flanke erkennen
        - POS_FLAG    => Positive Flnake erkennen
-----------------------------------------------------------------------------------------
 */

.syntax unified
.cpu cortex-m0
.thumb
.include "stm32f070.inc"

.text



/* 
WAIT(Cycle)
    Funktion:
        Programm n-Zyklen verzögern        

    Parameter:
        r0 : Wartezyklen

    Wartezyklen = Wartezeit / (4 * 1 / 8000000))
 */

.global wait
.thumb_func
wait:
wait_loop:
subs r0, #1
bne wait_loop
bx lr

/* 
MEMCLR(pSRC, LEN)
    Funktion:
        Datenbereich löschen

    Parameter:
        r0 => Quellenadresse
        r1 => Länge in Bytes
 */
 .global memclr
 .thumb_func
 memclr:
    cmp r1, #0
    beq func_end   // LEN == 0 ?
    movs r2, #0
    repeat:
    strb r2, [r0]  // löschen
    adds r0, #1    // Addresse inkrementieren
    subs r1, #1    // Schleifenzähler (LEN) dekrementieren
    bne repeat     // Schleifenzähler (LEN) > 0 ?
    func_end:
    bx lr

 /* 
MEMCPY(pSRC, pDEST, LEN)
    Funktion:
        Datenbereich umkopieren

    Parameter:
        r0 => Quellenadresse
        r1 => Zieladresse
        r2 => Länge in Bytes
 */
 .global memcpy
 .thumb_func
 memcpy:
    cmp r2, #0
    beq func_end_  // LEN == 0 ?
    ldrb r3, [r0]  // Quelldaten laden
    strb r3, [r1]  // Auf Zieladresse schreiben
    repeat_:
    adds r0, #1    // Quelladresse inkrementieren
    adds r1, #1    // Zieladresse inkrementieren
    subs r2, #1    // Schleifenzähler (LEN) dekrementieren
    bne repeat_    // Schleifenzähler (LEN) > 0 ?
    func_end_:
    bx lr

 /* 
NEG_FLAG(Sig, pMem)
    Funktion:
        Negative Flanke erkennen

    Parameter:
        r0 => Signalstatus
        r1 => Quellenadresse von Hilfsspeicher (Byte)

    Return:
        r0 => Flanke (Boolean)
 */
.global neg_flag
.thumb_func
neg_flag:
    push {r4}
    movs r4, #0
    ldrb r2, [r1]
    movs r3, r0
    mvns r3, r3
    ands r3, r2
    beq no_neg_flag
    ldr r4, =0xFFFFFFFF
    no_neg_flag:
    strb r0, [r1] // Aktueller Zustand in Hilfsspeicher sichern
    movs r0, r4
    pop {r4}
    bx lr

 /* 
NEG_FLAG(Sig, pMem)
    Funktion:
        Negative Flanke erkennen

    Parameter:
        r0 => Signalstatus
        r1 => Quellenadresse von Hilfsspeicher (Byte)
    
    Return:
        r0 => Flanke (Boolean)
 */
.global pos_flag
.thumb_func
pos_flag:
    push {r4}
    movs r4, #0
    ldrb r2, [r1]
    movs r3, r2
    mvns r3, r3
    ands r3, r0
    beq no_pos_flag
    ldr r4, =0xFFFFFFFF
    no_pos_flag:
    strb r0, [r1] // Aktueller Zustand in Hilfsspeicher sichern
    movs r0, r4
    pop {r4}
    bx lr
    
