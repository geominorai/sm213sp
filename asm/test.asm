.pos 0
init: irmovl stack, %esp
      irmovl stack, %ebp
      call main
      irmovl $0xFF, %edi
      halt

.pos 0x20
main: irmovl $0, %eax
      irmovl $32, %ecx
      irmovl $4, %edx
      loop:
      rrmovl %eax, %ebx
      mull %edx, %ebx
      rmmovl %eax, a(%ebx)
      irmovl $1, %ebx
      addl %ebx, %eax
      cmpl %eax, %ecx
      sleep $1
      jge loop
      ret

.pos 0x60
a:    .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      .long 0x0
      
.pos 0x100
stack:
