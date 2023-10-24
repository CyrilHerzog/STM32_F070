/* 
-----------------------------------------------------------------------------------------
Datei   : matrix.s
Autor   : Herzog Cyril
Version : 1.0
Datum   : 05.10.2023
-----------------------------------------------------------------------------------------

Beschreibung:
    Bibliothek für die Ansteuerung der Komponenten auf PCB - Print 
        - MATRIX_WRITE_ROW => Schreibe neue Matrix Daten 
        - MATRIX_READ_ROW  => Lesen der aktuellen Matrix Daten 
        _ MATRIX_BIT_SET   => Setze eine LED spezifisch an X,Y Koordinate
        - MATRIX_UPDATE    => Daten zur Matrix transferieren (Multiplexer)
-----------------------------------------------------------------------------------------
 */

.syntax unified
.cpu cortex-m0
.thumb
.include "stm32f070.inc"
.include "gpio.inc"

 .data
 matrix_data: 
 .byte 0 // row 0
 .byte 0 // row 1
 .byte 0 // row 2
 .byte 0 // row 3
 .byte 0 // row 4
 .byte 0 // row 5
 .byte 0 // row 6


.text

/* 
MATRIX_INIT()
    Funktion:
        Initialiserung für die Ansteuerung der Matrixanzeige
        Setzt den Datenspeicher auf 0 
        Konfiguriert die GPIO's        

    Parameter:
        Keine
 */

.global matrix_init
.thumb_func
 matrix_init:
    push {lr}
    // Matrix Daten löschen
    ldr r0, =matrix_data
    movs r1, #7
    bl memclr
    // GPIO Konfigurieren
    ldr r0, =GPIOA
    ldr r1, =pa5_cfg // clk
    bl gpio_config
    ldr r0, =GPIOA
    ldr r1, =pa7_cfg // dout
    bl gpio_config
    pop {pc}
    bx lr

    // Konfigurationsdaten
    pa5_cfg: 
	.byte GPIO_5
 	.byte GPIO_FUNC_MODE_OUTPUT
 	.byte GPIO_OUTPUT_MODE_PUSH_PULL
 	.byte GPIO_SPEED_MODE_LOW_SPEED
 	.byte GPIO_PULL_MODE_NO_PULL

    pa7_cfg: 
	.byte GPIO_7
 	.byte GPIO_FUNC_MODE_OUTPUT
 	.byte GPIO_OUTPUT_MODE_PUSH_PULL
 	.byte GPIO_SPEED_MODE_LOW_SPEED
 	.byte GPIO_PULL_MODE_NO_PULL


/* 
MATRIX_CLEAR()
    Funktion:
        Setzt alle Matrixdaten auf 0 
              
    Parameter:
        Keine
 */

.global matrix_clear
.thumb_func
 matrix_clear:
    push {lr}
    // Matrix Daten löschen
    ldr r0, =matrix_data
    movs r1, #7
    bl memclr
    pop {pc}

/* 
MATRIX_WRITE_ROW(data, row)
    Funktion:
        Schreibe Wert für die Zeile und Spalte        

    Parameter:
        r0 : data  
        r1 : row (0..6)

 */

.global matrix_write
.thumb_func
 matrix_write:
    cmp r1, #6
    bgt func_write_end    // Zeile > 6 ? => Fehler 
    cmp r1, #0
    blt func_write_end    // Zeile < 0 ? => Fehler
    ldr r2, =matrix_data
    adds r2, r1 
    strb r0, [r2]
    func_write_end:
    bx lr

/* 
(data) MATRIX_READ_ROW(row)
    Funktion:
        Schreibe Wert für die Zeile und Spalte        

    Parameter:
        r0 : row (0..6)

    Rückgabewert
        r0 : Daten der ganze Reihe

 */

.global matrix_read
.thumb_func
 matrix_read:
    cmp r0, #6
    bgt func_read_end    // Zeile > 6 ? => Fehler 
    cmp r0, #0
    blt func_read_end    // Zeile < 0 ? => Fehler
    ldr r1, =matrix_data
    adds r1, r0         // Adresse nach Zeile erhöhen 
    ldrb r0, [r1]       // Lese Spaltenwert in Zeile
    func_read_end:
    bx lr


/* 
(data) MATRIX_WRITE_BIT(x, y)
    Funktion:
        Schreibe Wert für die Zeile und Spalte        

    Parameter:
        r0 : x_kor (0..5)
        r1 : y_kor (0..6)

    Rückgabewert
        Keine

 */

.global matrix_write_bit
.thumb_func
matrix_write_bit:
    push {lr}
    cmp r0, #5
    bgt func_write_bit_end    // Spalte > 5 ? => Fehler 
    cmp r0, #0
    blt func_write_bit_end    // Spalte < 0 ? => Fehler
    movs r2, #1             
    lsls r2, r0
    mov r0, r2 
    bl matrix_write
    func_write_bit_end:
    pop {pc}

 
 /* 
MATRIX_UPDATE()
    Funktion:
        Schreibe Wert für die Zeilen aus den Matrixdaten in die Matrix
        Die Daten entsprechen C[0..5]
        L[0..6] wird durchmultiplext und die jeweiligen Zeilendaten übernommen
                
    Parameter:
        Keine

    Rückgabewert
        Keine

 */
.global matrix_update
.thumb_func
 matrix_update:
 push {lr}
 push {r4, r5, r6, r7}
 // Datenpacket auf richtige Bitpositionen stellen (Format 16Bit <=> Register 32Bit)
 ldr r7, =(1<<31)       // Vergleichswert für 7 durchläufe 
 ldr r5, =(1<<24)       // L[6..0] Startwert bei L0
 ldr r3, =matrix_data
 data_loop:
 // Datenformat => [N/A L6 L5 L4 L3 L2 L1 L0 N/A N/A C5 C4 C3 C2 C1 C0]
 movs r6, #16           // Bitzähler 
 ldrb r4, [r3]          // C[5..0]
 lsls r4, #16
 orrs r4, r5
 push {r3}              // r3 sichern => r3 kann im Zuge des Programmes verändert werden
 shift_loop:
 // Clock auf False setzen
 ldr r0, =GPIOA
 ldr r1, =GPIO_5
 movs r2, #0        // False
 bl gpio_write
 // Serial Out auf False setzen
 ldr r0, =GPIOA
 ldr r1, =GPIO_7
 movs r2, #0       // False
 bl gpio_write
 lsls r4, #1       // MSB von Datenpacket in das Carry schieben
 bcc carry_low     // Carry == 0 ?
 // Serial Out auf True setzen
 ldr r0, =GPIOA
 ldr r1, =GPIO_7
 movs r2, #1       // True        
 bl gpio_write
 carry_low:
 // Clock auf True setzen
 ldr r0, =GPIOA
 ldr r1, =GPIO_5
 movs r2, #1       // True 
 bl gpio_write
 subs r6, #1
 bne shift_loop
  // Clock auf False setzen => Datenübernahme
 ldr r0, =GPIOA
 ldr r1, =GPIO_5
 movs r2, #0       // False        
 bl gpio_write
 ldr r0, =3000     // Warten bevor neue Zeile aktiviert wird
 bl wait
 pop {r3}          // r3 Wiederherstellen => enthält Adresse der Matrix Daten
 adds r3, #1       // Adresse Matrix Daten inkrementieren
 lsls r5, #1       // Position Zeile (L) verschieben
 cmp r5, r7        
 beq update_end    // Alle Zeilen abgearbeitet ?
 b data_loop
 update_end:
 pop {r4, r5, r6, r7}
 pop {pc}
 bx lr 


