.pos 0
init: irmovl stack, %esp
      irmovl stack, %ebp
      call main
      irmovl $0xFF, %edi
      halt

.pos 0x20
main: 
      irmovl $8, %ecx ; # bots to use
      
      pushl %ebp
      rrmovl %esp, %ebp
      
      ; Say "Starting"
      irmovl $0, %ebx
      pushl %ebx ; arg1=nparams=0
      irmovl sa, %ebx
      pushl %ebx ; arg0=string addr
      call _cout
      
      ; Spawn bot
      call _spawnbot
      rrmovl %eax, %edx ; Backup client index value
      
      irmovl $3, %ebx ; Blue
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setteam
      
      irmovl $3, %ebx ; Soldier
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setclass
      
      pushl %edx ; arg0
      call _respawn
      
      ; Initialize zpos to -inf
      irmovl $0xff800000, %eax
      irmovl zmax, %ebx
      rmmovl %eax, 0x0(%ebx)
      
      sleep $80
      
      pushl %eax ; allocate arg (value doesn't matter)
      pushl %eax
      pushl %eax ; arg1=pos[3]
      pushl %edx ; arg0=iClient
      call _getpos
      mrmovl -4(%ebp), %ecx ; z-pos
      xorl %eax, %eax
      rmmovl %ecx, zbase(%eax) ; Starting z
      
      ; Strafe right, setlocal vel 400
      irmovl $0, %ebx ; 0.0
      pushl %ebx ; arg3
      irmovl $0x43c80000, %ebx ; 400.0
      pushl %ebx ; arg2
      irmovl $0, %ebx ; 0.0
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setlvel
      
      ; sleep $20
      
      ; Aim down
      irmovl $0, %ebx
      pushl %ebx ; arg2=ang[2]
      pushl %ebx ; arg2=ang[1]
      irmovl $0x42b20000, %ebx ; 89.0
      pushl %ebx ; arg1=ang[0]
      pushl %edx ; arg0
      call _setang
      
      sleep $20
      
      ; Do rocket jump
      irmovl $0x7, %ebx ; jump+crouch+fire button mask
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setbuttons
      sleep $10
      irmovl $0x0, %ebx ; release buttons
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setbuttons
      
      ; sleep $20

      irmovl $0, %edi
      
      ; Measure position
loop: pushl %eax ; allocate arg (value doesn't matter)
      pushl %eax
      pushl %eax ; arg1=pos[3]
      pushl %edx ; arg0=iClient
      call _getpos
      mrmovl -4(%ebp), %ecx ; z-pos
      
      xorl %eax, %eax
      rmmovl %ecx, zpos(%eax)
      
      xorl %eax, %eax ; 0x0
      fld zbase(%eax)
      fld zpos(%eax)
      fsub
      fst zhght(%eax)
      
      ; Print z-position to console
      mrmovl zhght(%eax), %ecx
      pushl %ecx
      pushl %edx
      irmovl $2, %ebx
      pushl %ebx ; arg1=nparams=1
      irmovl sb, %ebx
      pushl %ebx ; arg0=string addr
      ; call _chat
      call _cout
      
      fld zmax(%eax)
      fsub
      fstp st(0)
      
      jg skip
      fld zhght(%eax)
      fstp zmax(%eax)
      
skip: cmpl %ecx, %edi
      rrmovl %ecx, %edi
      sleep $1
      jne loop
      
      xorl %eax, %eax ; 0x0
      ; Print zmax to console
      mrmovl zmax(%eax), %ecx
      
      pushl %ecx
      pushl %edx
      irmovl $2, %ebx
      pushl %ebx ; arg1=nparams=1
      irmovl sd, %ebx
      pushl %ebx ; arg0=string addr
      ; call _chat
      call _cout
      
      ; Kick bot
      pushl %edx
      call _kickbot
      
      halt

.align 4
sa:   .ascii "*** Starting program ***"
sb:   .ascii "%L has z=%.1f"
sc:   .ascii "Iteration %d, client %d"
sd:   .ascii "%L had max z=%.1f"

se:   .ascii "Stopping"

scapa:.ascii "Begin data capture"
scapb:.ascii "End data capture"

.align 4
zpos: .long 0x0
zhght:.long 0x0
zmax: .long 0x0
zbase:.long 0x0
      
.pos 0x400
stack:
