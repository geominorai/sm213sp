.pos 0
init: irmovl stack, %esp
      irmovl stack, %ebp
      call main
      irmovl $0xFF, %edi
      halt

.pos 0x20
main: irmovl $0, %esi
      irmovl $15, %ecx
      
      pushl %ebp
      rrmovl %esp, %ebp
      
loop:
      rrmovl %esi, %ebx
      irmovl $4, %edx
      mull %edx, %ebx

      
      call _spawnbot
      rrmovl %eax, %edx ; Backup return value
      rmmovl %eax, a(%ebx)
      
      ; rrmovl %ebp, %esp
      ; popl %ebp
      
      
      
      irmovl $2, %ebx ; Red
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setteam
      
      irmovl $3, %ebx ; Soldier
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setclass
      
      pushl %edx ; arg0
      call _respawn
      
      ; Say "Starting"
      pushl %esi ; arg2=format param 0
      irmovl $1, %ebx
      pushl %ebx ; arg1=nparams
      irmovl sa, %ebx
      pushl %ebx ; arg1=string addr
      pushl %edx ; arg0=iClient
      call _say
      
      
      irmovl $0xc3c80000, %ebx ; -400.0
      pushl %ebx ; arg3
      pushl %ebx ; arg2
      ; irmovl $0, %ebx ; 0.0
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setlvel
      
      sleep $20
      irmovl $0x0, %ebx
      pushl %ebx ; arg3
      pushl %ebx ; arg2
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setlvel
      
      irmovl $1, %ebx
      addl %ebx, %esi
      cmpl %esi, %ecx
      sleep $2
      jge loop
      
      sleep $50
      
jump:
      irmovl $0, %esi
jumploop:
      ; sleep $10
      rrmovl %esi, %ebx
      irmovl $4, %edx
      mull %edx, %ebx
      
      mrmovl a(%ebx), %edx
      

      
      irmovl $0, %ebx
      pushl %ebx ; arg2=ang[2]
      pushl %ebx ; arg2=ang[1]
      irmovl $0x42b20000, %ebx ; 89.0
      pushl %ebx ; arg1=ang[0]
      pushl %edx ; arg0
      call _setang
      
      ; sleep $10
      
      ; irmovl $0x2, %ebx ; jump
      ; pushl %ebx ; arg1
      ; pushl %edx ; arg0
      ; call _setbuttons
      
      ; sleep $10
      
      ; irmovl $0x400, %ebx ; +moveright
      ; pushl %ebx ; arg1
      ; pushl %edx ; arg0
      ; call _setbuttons
      
           
      irmovl $0, %ebx ; 0.0
      pushl %ebx ; arg3
      irmovl $0x43c80000, %ebx ; 400.0
      pushl %ebx ; arg2
      irmovl $0, %ebx ; 0.0
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setlvel
      
      sleep $4
      
      irmovl $0x7, %ebx ; jump+crouch+fire
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setbuttons
      
      sleep $1
      
      irmovl $0, %ebx ; 0.0
      pushl %ebx ; arg3
      pushl %ebx ; arg2
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setlvel
      
      irmovl $0x0, %ebx ; crouch
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setbuttons
      
      pushl %eax
      pushl %eax
      pushl %eax ; arg1=pos[3]
      pushl %edx ; arg0=iClient
      call _getpos
      
      mrmovl -4(%ebp), %eax
      mrmovl -8(%ebp), %ebx
      mrmovl -12(%ebp), %edi
      
      ; Say finished
      pushl %eax
      pushl %ebx
      pushl %edi
      pushl %esi ; arg2=format param 0
      irmovl $4, %ebx
      pushl %ebx ; arg1=nparams
      irmovl sb, %ebx
      pushl %ebx ; arg1=string addr
      pushl %edx ; arg0=iClient
      call _say
      
      
      
      
      irmovl $1, %ebx
      addl %ebx, %esi
      cmpl %esi, %ecx
      sleep $1
      jge jumploop
      
      
      
      
      sleep $300
      
kick: irmovl $0, %esi
      ; irmovl $23, %ecx
      irmovl $4, %edx
loopkick:
      rrmovl %esi, %ebx
      mull %edx, %ebx
      
      mrmovl a(%ebx), %eax
      pushl %eax ; arg0
      
      call _kickbot      
      
      irmovl $1, %ebx
      addl %ebx, %esi
      cmpl %esi, %ecx
      ; sleep $10
      jge loopkick
      
      rrmovl %ebp, %esp
      popl %ebp
      ret
      

.align 4
sa:  .ascii "Starting %d"
sb:  .ascii "Finished %d at pos=[%.1f, %.1f, %.1f]"

.align 4
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

      
.align 4
zpos: .long 0x0
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
      
.pos 0x400
stack:
