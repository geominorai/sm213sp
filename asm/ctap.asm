.pos 0
init: irmovl stack, %esp
      irmovl stack, %ebp
      call main
      irmovl $0xFF, %edi
      halt

; SECTION: Kick Sspawn all bots
.pos 0x20
main: 
      irmovl $8, %ecx ; # bots to use
      
      pushl %ebp
      rrmovl %esp, %ebp
      
      ; Say "Starting"
      irmovl $0, %ebx
      pushl %ebx ; arg1=nparams=0
      irmovl sa, %ebx
      pushl %ebx ; arg1=string addr
      call _chat
      
      irmovl $0, %esi
spawnloop:
      rrmovl %esi, %ebx
      irmovl $4, %edx
      mull %edx, %ebx

      
      call _spawnbot
      rrmovl %eax, %edx ; Backup return value
      rmmovl %eax, a(%ebx)
      
      ; Initialize zpos array to -inf
      irmovl $0xff800000, %eax
      rmmovl %eax, zpos(%ebx)
      
      ; rrmovl %ebp, %esp
      ; popl %ebp
      
      
      
      ; irmovl $2, %ebx ; Red
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
      
      ; irmovl $0xc3c80000, %ebx ; -400.0
      ; pushl %ebx ; arg3
      ; pushl %ebx ; arg2
      ; pushl %ebx ; arg1
      ; pushl %edx ; arg0
      ; call _setlvel
      
      ; sleep $20
      ; irmovl $0x0, %ebx
      ; pushl %ebx ; arg3
      ; pushl %ebx ; arg2
      ; pushl %ebx ; arg1
      ; pushl %edx ; arg0
      ; call _setlvel
      
      incl %esi
      cmpl %esi, %ecx
      ; sleep $2
      jg spawnloop
      
      sleep $70
      
; SECTION: RJump all bots
      irmovl $0, %esi
strafeloop:
      ; sleep $10
      rrmovl %esi, %ebx
      irmovl $4, %edx
      mull %edx, %ebx
      
      mrmovl a(%ebx), %edx ; Restore saved client ID from array
 
      irmovl $0, %ebx
      pushl %ebx ; arg2=ang[2]
      pushl %ebx ; arg2=ang[1]
      irmovl $0x42b20000, %ebx ; 89.0
      pushl %ebx ; arg1=ang[0]
      pushl %edx ; arg0
      call _setang
            
      irmovl $0, %ebx ; 0.0
      pushl %ebx ; arg3
      irmovl $0x43c80000, %ebx ; 400.0
      pushl %ebx ; arg2
      irmovl $0, %ebx ; 0.0
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setlvel
      
      incl %esi
      cmpl %esi, %ecx
      ; sleep $1
      jg strafeloop
      
      sleep $4
      
      irmovl $0, %esi
jumploop:      
      rrmovl %esi, %ebx
      irmovl $4, %edx
      mull %edx, %ebx
      
      mrmovl a(%ebx), %edx ; Restore saved client ID from array
      
      irmovl $0x7, %ebx ; jump+crouch+fire
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setbuttons
      
      incl %esi
      cmpl %esi, %ecx
      ; sleep $1
      jg jumploop
      
      sleep $10
      
      irmovl $0, %esi
stoploop:
      rrmovl %esi, %ebx
      irmovl $4, %edx
      mull %edx, %ebx

      mrmovl a(%ebx), %edx ; Restore saved client ID from array
      
      irmovl $0, %ebx ; 0.0
      pushl %ebx ; arg3
      pushl %ebx ; arg2
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setlvel
      
      irmovl $0x0, %ebx ; release
      pushl %ebx ; arg1
      pushl %edx ; arg0
      call _setbuttons
      
      incl %esi
      cmpl %esi, %ecx
      ; sleep $1
      jg stoploop
      
      sleep $30

; SECTION: Store maxheights
      ; Say begin capture
      irmovl $0, %ebx
      pushl %ebx ; arg1=nparams
      irmovl scapa, %ebx
      pushl %ebx ; arg1=string addr
      call _chat
    
      irmovl $100, %edi
storeloop:
      irmovl $0, %esi
      
storeloopinner:
      rrmovl %esi, %ebx
      irmovl $4, %edx
      mull %edx, %ebx
      

      mrmovl a(%ebx), %edx ; Restore saved client ID from array
      
      ; pushl %edx
      ; pushl %edi
      ; irmovl $2, %ebx
      ; pushl %ebx ; arg1=nparams=2
      ; irmovl sc, %ebx
      ; pushl %ebx ; arg1=string addr
      ; call _chat
      
      
      
      pushl %eax ; allocate arg
      pushl %eax
      pushl %eax ; arg1=pos[3]
      pushl %edx ; arg0=iClient
      call _getpos
      
      mrmovl -12(%ebp), %eax ; z
      
      ; Say max zpos
      ; pushl %eax ; arg2=format param 0
      ; irmovl $1, %ebx
      ; pushl %ebx ; arg1=nparams
      ; irmovl sd, %ebx
      ; pushl %ebx ; arg1=string addr
      ; pushl %edx ; arg0=iClient
      ; call _say
      
      rrmovl %esi, %ebx
      irmovl $4, %edx
      mull %edx, %ebx

      mrmovl zpos(%ebx), %edx ; old z
      cmpl %eax, %edx
      jle skip
      rmmovl %eax, zpos(%ebx)
      
skip: incl %esi
      cmpl %esi, %ecx
      ; sleep $1
      jg storeloopinner
      
      sleep $1
      
      decl %edi
      testl %edi, %edi
      jge storeloop
      
    
      ; Say end capture
      irmovl $0, %ebx
      pushl %ebx ; arg1=nparams
      irmovl scapb, %ebx
      pushl %ebx ; arg1=string addr
      call _chat
    
    sleep $100
      
; SECTION: Output max z
    irmovl $0, %esi
zloop:
    rrmovl %esi, %ebx
    irmovl $4, %edx
    mull %edx, %ebx
    

    mrmovl a(%ebx), %edx
    mrmovl zpos(%ebx), %eax
    
    ; Say max zpos
    pushl %eax ; arg2=format param 0
    irmovl $1, %ebx
    pushl %ebx ; arg1=nparams
    irmovl sd, %ebx
    pushl %ebx ; arg1=string addr
    pushl %edx ; arg0=iClient
    call _say
    
    incl %esi
    cmpl %esi, %ecx
    sleep $1
    jg zloop
    
; SECTION: Kick all bots

      irmovl $0, %esi
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
      jg loopkick
      
      rrmovl %ebp, %esp
      popl %ebp
      ret
      

.align 4
sa:   .ascii "*** Starting program ***"
sb:   .ascii "Finished %d at pos=[%.1f, %.1f, %.1f]"
sc:   .ascii "Iteration %d, client %d"
sd:   .ascii "max z=%.1f"

se:   .ascii "Stopping"

scapa:.ascii "Begin data capture"
scapb:.ascii "End data capture"

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
