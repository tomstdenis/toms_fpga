.ALIGN 0x10
:funcname
.IREG foo
.REG bar
.REG baz
.PUSHREGS
	ADD foo,bar,baz
.POPREGS
	RET

.ALIGN 0x10
:funcname2
.IREG bar
.REG baz
.REG foo
.PUSHREGS
	ADD foo,bar,baz
.POPREGS
	RET
