# Memory Map Constants
.equ UART_BASE,   0x20000000
.equ UART_STATUS, 0x08
.equ UART_DATA,   0x0C
.equ TX_FULL_BIT, 0x02         # Bit 1 is FULL

_start:
    li t0, UART_BASE
    li t1, 0x41                 # 'A'

wait_tx:
#    lw   t2, UART_STATUS(t0)
#    andi t2, t2, TX_FULL_BIT
#    bnez t2, send_char # hax    # IF bit is 1 (Full), LOOP and wait.
                        # IF bit is 0 (Room available), FALL THROUGH.

send_char:
    sw   t1, UART_DATA(t0)   # Write 'A' to UART_DATA
    j    wait_tx
