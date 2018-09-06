! $Id$
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
!
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
!***************************************************************
module Diagnostics
!
  use Cdata
  use Messages
  use Mpicomm
!
  implicit none
!
  private
!
  public :: initialize_diagnostics, prints
  public :: diagnostic, initialize_time_integrals,get_average_density
  public :: xyaverages_z, xzaverages_y, yzaverages_x
  public :: phizaverages_r, yaverages_xz, zaverages_xy
  public :: phiaverages_rz
  public :: write_1daverages, write_2daverages
  public :: write_sound
  public :: write_2daverages_prepare, write_zaverages
  public :: expand_cname, parse_name, fparse_name, save_name, save_name_halfz
  public :: save_name_sound
  public :: name_is_present
  public :: max_name, sum_name
  public :: max_mn_name, sum_mn_name, integrate_mn_name, sum_weighted_name
  public :: integrate_mn
  public :: sum_mn_name_halfy, surf_mn_name, sum_lim_mn_name
  public :: sum_mn_name_halfz
  public :: xysum_mn_name_z, xzsum_mn_name_y, yzsum_mn_name_x
  public :: phizsum_mn_name_r, ysum_mn_name_xz, zsum_mn_name_xy
  public :: phisum_mn_name_rz, calc_phiavg_profile
  public :: yzintegrate_mn_name_x, xzintegrate_mn_name_y, xyintegrate_mn_name_z
  public :: allocate_fnames,allocate_vnames,allocate_sound
  public :: allocate_xyaverages, allocate_xzaverages, allocate_yzaverages
  public :: allocate_phizaverages
  public :: allocate_yaverages, allocate_zaverages, allocate_phiaverages
  public :: fnames_clean_up,vnames_clean_up,sound_clean_up
  public :: xyaverages_clean_up, xzaverages_clean_up, yzaverages_clean_up
  public :: phizaverages_clean_up
  public :: yaverages_clean_up, zaverages_clean_up, phiaverages_clean_up
  public :: get_from_fname
  public :: init_xaver
  public :: gen_form_legend
  public :: ysum_mn_name_xz_npar, xysum_mn_name_z_npar, zsum_mn_name_xy_mpar, yzsum_mn_name_x_mpar
!
  interface max_name
    module procedure max_name_int
    module procedure max_name_real
  endinterface max_name
!
  interface expand_cname
    module procedure expand_cname_short
    module procedure expand_cname_full
  endinterface expand_cname
!
  interface parse_name
    module procedure parse_name_s
    module procedure parse_name_sa
    module procedure parse_name_v
  endinterface parse_name
!
  interface sum_mn_name
    module procedure sum_mn_name_real
    module procedure sum_mn_name_arr2
    module procedure sum_mn_name_std
  endinterface sum_mn_name
!
  real, dimension (nrcyl,nx) :: phiavg_profile=0.0
  real :: dVol_rel1

  integer :: mnamer
  character (len=intlen) :: ch2davg
!
  contains
!***********************************************************************
    subroutine initialize_diagnostics()
!
!  Setup variables needed for output of diagnostic quantities and
!  averages.
!
!  14-aug-03/axel: added dxy, dyz, and dxz
!  26-aug-13/MR: removed switch first; moved calculation of dVol_rel1 from diagnostic
!  31-mar-15/MR: added switch for proper volume averaging
!
      integer :: i
      real :: dxeff,dyeff,dzeff
      real :: intdr_rel, intdtheta_rel, intdphi_rel, intdz_rel
!
!  Initialize rcyl for the phi-averages grid. Does not need to be
!  done after each reload of run.in, but this is the easiest way
!  of doing it.
!
      if (nrcyl/=0) then
        drcyl=xyz1(1)/nrcyl
      else
        drcyl=0.0
      endif
      rcyl=(/ ((i-0.5)*drcyl, i=1,nrcyl) /)
!
!  Calculate the three surface elements. Take care of degenerate dimensions.
!
      if (nxgrid==1) then; dxeff=1.; else; dxeff=dx; endif
      if (nygrid==1) then; dyeff=1.; else; dyeff=dy; endif
      if (nzgrid==1) then; dzeff=1.; else; dzeff=dz; endif
!
      dsurfxy=dxeff*dyeff
      dsurfyz=dyeff*dzeff
      dsurfzx=dzeff*dxeff
!
!  Calculate relative volume integral.
!
      if (lproper_averages) then
        dVol_rel1=1./box_volume
      elseif (lspherical_coords) then
!
        intdr_rel     =      (xyz1(1)**3-    xyz0(1)**3)/(3.*dx)
        intdtheta_rel = -(cos(xyz1(2))  -cos(xyz0(2)))/dy
        intdphi_rel   =      (xyz1(3)   -    xyz0(3)) /dz
!
!  Prevent zeros from less than 3-dimensional runs
!  (maybe this should be 2pi, but maybe not).
!
        if (nx==1) intdr_rel=1.0
        if (ny==1) intdtheta_rel=1.0
        if (nz==1) intdphi_rel=1.0
!
        dVol_rel1=1./(intdr_rel*intdtheta_rel*intdphi_rel)
!
      elseif (lcylindrical_coords) then
!
        intdr_rel   =      (xyz1(1)**2-    xyz0(1)**2)/(2.*dx)
        intdphi_rel =      (xyz1(2)   -    xyz0(2)) /dy
        intdz_rel   =      (xyz1(3)   -    xyz0(3)) /dz
!
!  Prevent zeros from less than 3-dimensional runs.
!
        if (nx==1) intdr_rel=1.0
        if (ny==1) intdphi_rel=1.0
        if (nz==1) intdz_rel=1.0
!
        dVol_rel1=1./(intdr_rel*intdphi_rel*intdz_rel)
!
      else
        dVol_rel1=1./nwgrid
      endif
!
      if (lroot.and.ip<=10) print*,'dVol_rel1=',dVol_rel1

    endsubroutine initialize_diagnostics
!***********************************************************************
    subroutine prints
!
!  Reads and registers print parameters gathered from the different
!  modules and marked in `print.in'.
!
!   3-may-02/axel: coded
!  20-aug-13/MR: changes for accumulating and complex diagnostics
!  26-aug-13/MR: corrected insertion of imaginary values
!
      use General, only: safe_character_append
      use Cparam, only: max_col_width
      use Sub, only: insert
!
      logical,save :: lfirst_call=.true.
      character (len=640) :: fform,legend,line
      integer :: iname, iostat, nnamel
      character(LEN=linelen) :: iomsg
      logical :: lop
      real, dimension(2*nname) :: buffer
      integer, parameter :: lun=1
!
!  Add general (not module-specific) quantities for diagnostic output. If the
!  timestep (=dt) is to be written, it is known only after time_step, so the best
!  place to enter it into the save list is here. Use 1.0*(it-1) to have floating
!  point or double precision.
!
      if (lroot) then
        if (idiag_t /=0)  call save_name(tdiagnos,idiag_t)
        if (idiag_dt/=0)  call save_name(dt,idiag_dt)
        if (idiag_it/=0)  call save_name(one_real*(it-1),idiag_it)
      endif
!
      if (lroot) then
!
!  Whenever itype_name=ilabel_max_dt, scale result by dt (for printing Courant
!  time).
!
        do iname=1,nname
          if (itype_name(iname)==ilabel_max_dt) fname(iname)=dt*fname(iname)
        enddo

        call gen_form_legend(fform,legend)
!
        if (ldebug) then
          write(0,*) 'PRINTS.prints: format = ', trim(fform)
          write(0,*) 'PRINTS.prints: args   = ', fname(1:nname)
        endif
!
!  This treats all numbers as floating point numbers.  Only those numbers are
!  given (and computed) that are also listed in print.in.
!
        if (lfirst_call) then
          write(*,*)
          write(*,'(" ",A)') trim(legend)
        endif
!
!  Write legend to extra file (might want to do only once after each lreset)
!
        if (lfirst_call) then
!
          open(lun,file=trim(datadir)//'/legend.dat',IOSTAT=iostat,iomsg=iomsg)
          if (.not. outlog(iostat,'openw',trim(datadir)//'/legend.dat', &
                           location='prints',iomsg=iomsg)) then
!
            write(lun,'(" ",A)',IOSTAT=iostat,iomsg=iomsg) trim(legend)
            if (.not. outlog(iostat,'legend',iomsg=iomsg)) then
!
              close(lun,IOSTAT=iostat,iomsg=iomsg)
              if (outlog(iostat,'close',iomsg=iomsg)) continue
!
            endif
          endif
        endif
!
!  Put output line into a string.
!
        if (ldebug) write(*,*) 'bef. writing prints'
        buffer(1:nname) = fname(1:nname)
!
!  add accumulated values to current ones if existent
!
        where( fname_keep(1:nname) /= impossible .and. &
               itype_name(1:nname)<ilabel_complex ) &
           buffer(1:nname) = buffer(1:nname)+fname_keep(1:nname)
!
        nnamel=nname
        do iname=nname,1,-1
          if (itype_name(iname)>=ilabel_complex) then
            call insert(buffer,(/fname_keep(iname)/),iname+1,nnamel)
          endif
        enddo
!
        write(line,trim(fform)) buffer(1:nnamel)
        call clean_line(line)
!
!  Append to diagnostics file.
!
        inquire(lun,opened=lop)
        if (.not.lop) &
          open(lun,file=trim(datadir)//'/time_series.dat',position='append',IOSTAT=iostat,iomsg=iomsg)
!  file not distributed, backskipping enabled
        if (lop .or. .not.outlog(iostat,'openw',trim(datadir)//'/time_series.dat',dist=-1,iomsg=iomsg)) then
!
          if (lfirst_call) then
            write(lun,"('"//comment_char//"',a)",IOSTAT=iostat,iomsg=iomsg) trim(legend)
            if (.not. outlog(iostat,'legend',iomsg=iomsg)) continue
          endif
!
          write(lun,'(a)',IOSTAT=iostat,iomsg=iomsg) trim(line)
          if (.not. outlog(iostat,'line',iomsg=iomsg)) then
!
            close(lun,IOSTAT=iostat,iomsg=iomsg)
            if (outlog(iostat,'close',iomsg=iomsg)) continue
!
          endif
        endif
!
!  Write to stdout.
!
        write(*,'(a)') trim(line)
        flush(6)
!
      endif                     ! (lroot)
!
      if (ldebug) write(*,*) 'exit prints'
      lfirst_call = .false.
!
!  reset non-accumulating values (marked with zero in fname_keep)
!
      where( fname_keep(1:nname)==0. .or. &
             itype_name(1:nname)>=ilabel_complex ) fname(1:nname)=0.
      where( itype_name(1:nname)>=ilabel_complex ) fname_keep(1:nname)=0.
!
    endsubroutine prints
!***********************************************************************
    subroutine gen_form_legend(fform,legend)
!
!  19-aug-13/MR: outsourced from prints
!
      use General, only: safe_character_append
      use Sub, only: noform
!
      character (len=640)          ,intent(OUT) :: fform
      character (len=640), optional,intent(OUT) :: legend
!
      character, parameter :: comma=','
      character(len=40)    :: tform
      integer              :: iname
      logical              :: lcompl
!
!  Produce the format.
!
        fform = '(TL1'
        if (present(legend)) legend=''
!
        do iname=1,nname

          lcompl=itype_name(iname)>=ilabel_complex

          if (lcompl) then
            tform = comma//'" ("'//comma//trim(cform(iname))//comma &
              //'","'//comma//trim(cform(iname))//comma//'")"'
          else
            tform = comma//trim(cform(iname))
          endif
          call safe_character_append(fform, trim(tform))
          if (present(legend)) call safe_character_append(legend, noform(cname(iname),lcompl))

        enddo
        call safe_character_append(fform, ')')
!
    endsubroutine gen_form_legend
!***********************************************************************
    subroutine clean_line(line)
!
!  removes spurious dots from line, makes it to comment line if unreadable
!
!  14-jan-11/MR: outsourced from prints
!
    character (LEN=*), intent(inout) :: line
    integer :: ind
!
!  If line contains spurious dots, remove them.
!
      ind=index(line,'. ')
      if (ind >= 1) line(ind:ind)=' '
!
!  If the line contains unreadable characters, then comment out line.
!
      ind=index(line,'***') + index(line,'???')
      if (ind > 0) line(1:1)=comment_char
!
    endsubroutine clean_line
!***********************************************************************
    subroutine write_sound_append(legend,sublegend,coorlegend,line)
!
!  Append to diagnostics file.
!
!  27-Nov-2014/Bourdin.KIS: cleaned up code from write_sound
!
      character (len=*), intent(in) :: legend, sublegend, coorlegend, line
!
      logical, save :: lfirst_call=.true.
      integer, parameter :: lun=1
      integer :: iostat
      character(LEN=linelen) :: iomsg
!
        open(lun,file=trim(directory)//'/sound.dat',position='append',IOSTAT=iostat,iomsg=iomsg)
! file distributed (???), backskipping enabled
        if (outlog(iostat,'openw',trim(directory)//'/sound.dat',dist=1, &
                   location='write_sound_append',iomsg=iomsg)) return
!
        if (lfirst_call) then
!
          write(lun,'(a)',IOSTAT=iostat,iomsg=iomsg) trim(legend)
          if (outlog(iostat,'legend',iomsg=iomsg)) return
!
          if (dimensionality>0) then
!
            write(lun,'(a)',IOSTAT=iostat,iomsg=iomsg) trim(coorlegend)
            if (outlog(iostat,'coorlegend',iomsg=iomsg)) return
!
            if ( ncoords_sound>1 ) then
              write(lun,'(a)',IOSTAT=iostat,iomsg=iomsg) trim(sublegend)
              if (outlog(iostat,'sublegend',iomsg=iomsg)) return
            endif
!
            write(lun,'(a)',IOSTAT=iostat,iomsg=iomsg) comment_char//repeat('-',len_trim(legend)-1)
            if (outlog(iostat,'comment',iomsg=iomsg)) return
!
          endif
        endif
!
        write(lun,'(a)',IOSTAT=iostat,iomsg=iomsg) trim(line)
        if (outlog(iostat,'line',iomsg=iomsg)) return
!
        close(lun,IOSTAT=iostat,iomsg=iomsg)
        if (outlog(iostat,'close',iomsg=iomsg)) continue
!
    endsubroutine write_sound_append
!***********************************************************************
    subroutine write_sound(tout)
!
!  Reads and registers "sound" parameters gathered from the different
!  modules and marked in `sound.in'.
!
!   3-dec-10/dhruba+joern: coded
!  10-jan-11/MR: modified
!
      use General, only: itoa, safe_character_append, safe_character_prepend
      use Sub    , only: noform
!
      implicit none
!
      real, intent(in) :: tout
!
      logical, save :: lfirst_call=.true.
      logical :: ldata
      character (len=linelen*3) :: fform,legend,sublegend,coorlegend,line
      character (len=*), parameter :: tform='(f10.4'
      integer, parameter :: ltform=10
      character (len=ltform) :: scoor
      character (len=3*ncoords_sound*max_col_width) :: item
      real    :: coor
      integer :: iname,leng,nc,nch,nleg,nsub,idim,icoor,i,j
!
!  Produce the format.
!
      fform = tform//','
      if ( ncoords_sound>1 ) then
        call safe_character_append(fform, trim(itoa(ncoords_sound))//'(')
      endif
!
      if (lfirst_call) then
!
        legend = comment_char//noform('t'//tform//')')
!
        if (dimensionality>0) then
!
          coorlegend = comment_char//' Points:   '
          nleg = len_trim(coorlegend)+3
!
          do icoor=1,ncoords_sound
!
            coorlegend(nleg+1:) = trim(itoa(icoor))//' = '
            nleg = len_trim(coorlegend)+1
!
            item = '('
            do idim=1,dimensionality
              select case (idim)
              case (1); coor=x(sound_coords_list(icoor,1))
              case (2); coor=y(sound_coords_list(icoor,2))
              case (3); coor=z(sound_coords_list(icoor,3))
              case default
              end select
              write(scoor,tform//')')coor
              call safe_character_append(item,trim(adjustl(scoor))//',')
            enddo
            coorlegend(nleg+1:) = item(1:len_trim(item)-1)//'),   '
            nleg = len_trim(coorlegend)+4
!
          enddo
          coorlegend(nleg-4:nleg)=' '
        endif
!
      endif
!
      ldata = .false.
      sublegend = comment_char
!
      do iname=1,nname_sound
!
        if (cform_sound(iname)/=' ') then
          ldata=.true.
          if (lfirst_call) then
!
            item = noform(cname_sound(iname))
            if ( ncoords_sound>1 ) then
!
              nsub = len_trim(legend)
              leng = len_trim(item)
              nc  = leng*(ncoords_sound-1) ; nch = nc/2
              if (nch>0) call safe_character_prepend(item,repeat('-',nch) )
              call safe_character_append(item,repeat('-',nc-nch) )
!
              nch = (leng-2)/2
              do icoor=1,ncoords_sound
                write(sublegend(nsub+nch+1:nsub+nch+2),'(i2)') icoor
                nsub = nsub+leng
              enddo
            endif
            call safe_character_append(legend, item)
!
          endif
          call safe_character_append(fform, trim(cform_sound(iname))//',')
        endif
!
      enddo
!
!  Put output line into a string.
!
      if (ldata) then
        fform = fform(1:len_trim(fform)-1)
        if ( ncoords_sound>1 ) call safe_character_append(fform, ')')
        write(line,trim(fform)//')') tout, ((fname_sound(i,j),  &
            j=1,ncoords_sound), i=1,nname_sound)
               !(1:nname_sound,1:ncoords_sound)
      else
        write(line,tform//')')tout
      endif
!
      call clean_line(line)
      call write_sound_append(legend,sublegend,coorlegend,line)
!
      if (ldebug) write(*,*) 'exit write_sound'
      lfirst_call = .false.
!
      fname_sound(1:nname_sound,1:ncoords_sound)=0.0
!
    endsubroutine write_sound
!***********************************************************************
    subroutine get_average_density(mass_per_proc,average_density)
!
!  Finalize calculation of diagnostic quantities (0-D).
!
!   1-dec-09/dhruba+piyali: adapted from diagnostic
!   3-may-12/axel+MR: to divide by box_volume, not nw
!
      real :: mass_per_proc,average_density
      intent(out) :: average_density
      intent(in) :: mass_per_proc
!
      real :: mass
!
!  Communicate over all processors.
!
      call mpireduce_sum(mass_per_proc,mass)
!
!  The result is present everywhere
!
      average_density=mass/box_volume
      call mpibcast_real(average_density)
!
    endsubroutine get_average_density
!**********************************************************************
    subroutine diagnostic(vname,nlname,lcomplex)
!
!  Finalize calculation of diagnostic quantities (0-D).
!
!   2-sep-01/axel: coded
!  14-aug-03/axel: began adding surface integrals
!  26-aug-13/MR:   moved calculation of dVol_rel1 to initialize_diagnostics
!                  added optional parameter lcomplex for use with imaginary part
!
      use General, only: loptest
!
      integer,                 intent(in)   :: nlname
      real, dimension(nlname), intent(inout):: vname
      logical,optional,        intent(in)   :: lcomplex
!
      real, dimension (nlname) :: fmax_tmp, fsum_tmp, fmax, fsum, fweight_tmp
      real :: vol
      integer :: iname, imax_count, isum_count, nmax_count, nsum_count, itype
      logical :: lweight_comm, lalways
!
!  Go through all print names, and sort into communicators
!  corresponding to their type.
!
      imax_count=0
      isum_count=0
      lweight_comm=.false.

      lalways=.not.loptest(lcomplex)

      do iname=1,nlname

        itype = itype_name(iname)

        if (lalways.or.itype>=ilabel_complex) then
          if (itype<0) then
            imax_count=imax_count+1
            fmax_tmp(imax_count)=vname(iname)
          elseif (itype>0) then
            itype = mod(itype,ilabel_complex)
            isum_count=isum_count+1
            fsum_tmp(isum_count)=vname(iname)
            if (itype==ilabel_sum_weighted .or. &
                itype==ilabel_sum_weighted_sqrt .or. &
                itype==ilabel_sum_par .or. &
                itype==ilabel_sum_sqrt_par .or. &
                itype==ilabel_sum_log10_par) then
              fweight_tmp(isum_count)=fweight(iname)
              lweight_comm=.true.
            endif
          endif
        endif
      enddo
      nmax_count=imax_count
      nsum_count=isum_count

      if (nmax_count==0 .and. nsum_count==0) return
!
!  Communicate over all processors.
!
      call mpireduce_max(fmax_tmp,fmax,nmax_count,comm=MPI_COMM_WORLD) ! only for scalars!
!
      call mpireduce_sum(fsum_tmp,fsum,nsum_count)
      if (lweight_comm) call mpireduce_sum(fweight_tmp,fweight,nsum_count)
!
!  The result is present only on the root processor.
!
      if (lroot) then
!
!  Sort back into original array.
!
        imax_count=0
        isum_count=0
        do iname=1,nlname
!
          itype = itype_name(iname)
          if (lalways.or.itype>=ilabel_complex) then

            if (itype<0) then ! max
              imax_count=imax_count+1
!
              if (itype==ilabel_max)            &
                  vname(iname)=fmax(imax_count)
!
              if (itype==ilabel_max_sqrt)       &
                  vname(iname)=sqrt(fmax(imax_count))
!
              if (itype==ilabel_max_dt)         &
                  vname(iname)=fmax(imax_count)
!
              if (itype==ilabel_max_neg)        &
                  vname(iname)=-fmax(imax_count)
!
              if (itype==ilabel_max_reciprocal) &
                  vname(iname)=1./fmax(imax_count)
!
            elseif (itype>0) then
!
              itype = mod(itype,ilabel_complex)
              isum_count=isum_count+1
!
              if (itype==ilabel_sum)            &
                  vname(iname)=fsum(isum_count)*dVol_rel1
!
              if (itype==ilabel_sum_sqrt)       &
                  vname(iname)=sqrt(fsum(isum_count)*dVol_rel1)
!
              if (itype==ilabel_sum_par)        &
                  vname(iname)=fsum(isum_count)/fweight(isum_count)
!
              if (itype==ilabel_sum_sqrt_par)        &
                  vname(iname)=sqrt(fsum(isum_count))/fweight(isum_count)
!
              if (itype==ilabel_sum_log10_par)        &
                  vname(iname)=log10(fsum(isum_count)/fweight(isum_count))
!
              if (itype==ilabel_integrate)      &
                  vname(iname)=fsum(isum_count)
!
              if (itype==ilabel_integrate_sqrt)      &
                  vname(iname)=sqrt(fsum(isum_count))
!
              if (itype==ilabel_integrate__log10)      &
                  vname(iname)=log10(fsum(isum_count))
!
               if (itype==ilabel_surf)          &
                   vname(iname)=fsum(isum_count)
!
               if (itype==ilabel_sum_lim) then
                  vol=1.
                  if (lcylinder_in_a_box)  vol=vol*pi*(r_ext**2-r_int**2)
                  if (nzgrid/=1)           vol=vol*Lz
                  if (lsphere_in_a_box)    vol=1.333333*pi*(r_ext**3-r_int**3)
                  vname(iname)=fsum(isum_count)/vol
               endif
!
              if (itype==ilabel_sum_weighted) then
                if (fweight(isum_count)/=0.0) then
                  vname(iname)=fsum(isum_count)/fweight(isum_count)
                else
                  vname(iname)=0.0
                endif
              endif
!
              if (itype==ilabel_sum_weighted_sqrt) then
                if (fweight(isum_count)/=0.0) then
                  vname(iname)=sqrt(fsum(isum_count)/fweight(isum_count))
                else
                  vname(iname)=0.0
                endif
              endif
!
            endif
          endif
        enddo
!
      endif
!
    endsubroutine diagnostic
!***********************************************************************
    subroutine initialize_time_integrals(f)
!
!  Initialize time_integrals for full chunks.
!
!  28-jun-07/axel+mreinhard: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      intent(inout) :: f
!
      if (iuut/=0) f(:,:,:,iuxt:iuzt)=0.0
      if (ioot/=0) f(:,:,:,ioxt:iozt)=0.0
      if (ibbt/=0) f(:,:,:,ibxt:ibzt)=0.0
      if (ijjt/=0) f(:,:,:,ijxt:ijzt)=0.0
!
    endsubroutine initialize_time_integrals
!***********************************************************************
    subroutine xyaverages_z()
!
!  Calculate xy-averages (still depending on z)
!  NOTE: these averages depend on z, so after summation in x and y they
!  are still distributed over nprocz CPUs; hence the dimensions of fsumz
!  (and fnamez).
!  In other words: the whole xy-average is present in one and the same fsumz,
!  but the result is not complete on any of the processors before
!  mpireduce_sum has been called. This is simpler than collecting results
!  first in processors with the same ipz and different ipy, and then
!  assemble result from the subset of ipz processors which have ipy=0
!  back on the root processor.
!
!   6-jun-02/axel: coded
!
      real, dimension (nz,nprocz,nnamez) :: fsumz
!
!  Communicate over all processors.
!  The result is only present on the root processor
!
      if (nnamez>0) then
        call mpireduce_sum(fnamez,fsumz,(/nz,nprocz,nnamez/))
        if (lroot) &
            fnamez(:,:,1:nnamez)=fsumz(:,:,1:nnamez)/nxygrid
      endif
!
    endsubroutine xyaverages_z
!***********************************************************************
    subroutine xzaverages_y()
!
!  Calculate xz-averages (still depending on y).
!
!  12-oct-05/anders: adapted from xyaverages_z
!
      real, dimension (ny,nprocy,nnamey) :: fsumy
!
!  Communicate over all processors.
!  The result is only present on the root processor.
!
      if (nnamey>0) then
        call mpireduce_sum(fnamey,fsumy,(/ny,nprocy,nnamey/))
        if (lroot) &
            fnamey(:,:,1:nnamey)=fsumy(:,:,1:nnamey)/nxzgrid
      endif
!
    endsubroutine xzaverages_y
!***********************************************************************
    subroutine yzaverages_x()
!
!  Calculate yz-averages (still depending on x).
!
!   2-oct-05/anders: adapted from xyaverages_z
!
      real, dimension (nx,nprocx,nnamex) :: fsumx
!
!  Communicate over all processors.
!  The result is only present on the root processor.
!
      if (nnamex>0) then
        call mpireduce_sum(fnamex,fsumx,(/nx,nprocx,nnamex/))
        if (lroot) &
            fnamex(:,:,1:nnamex)=fsumx(:,:,1:nnamex)/nyzgrid
      endif
!
    endsubroutine yzaverages_x
!***********************************************************************
    subroutine phizaverages_r()
!
!  Calculate phiz-averages (still depending on r).
!
!  29-jan-07/wlad: adapted from yzaverages_x and phiaverages_rz
!
      real, dimension (nrcyl,nnamer) :: fsumr
      real, dimension (nrcyl) :: norm
      integer :: in
!
!  Communicate over all processors.
!  The result is only present on the root processor.
!
      if (nnamer>0) then
        !the extra slot is where the normalization is stored
        call mpireduce_sum(fnamer,fsumr,(/nrcyl,nnamer/))
        if (lroot) then
           norm=fsumr(:,nnamer+1)
           do in=1,nnamer
             fnamer(:,in)=fsumr(:,in)/norm
           enddo
        endif
      endif
!
    endsubroutine phizaverages_r
!***********************************************************************
    subroutine yaverages_xz()
!
!  Calculate y-averages (still depending on x and z).
!
!   7-jun-05/axel: adapted from zaverages_xy
!
      real, dimension (nx,nz,nnamexz) :: fsumxz
!
!  Communicate over all processors along y beams.
!  The result is only present on the y-root processors.
!
      if (nnamexz>0) then
        call mpireduce_sum(fnamexz,fsumxz,(/nx,nz,nnamexz/),idir=2)
        if (lfirst_proc_y) fnamexz(:,:,1:nnamexz)=fsumxz(:,:,1:nnamexz)/nygrid
      endif
!
    endsubroutine yaverages_xz
!***********************************************************************
    subroutine zaverages_xy()
!
!  Calculate z-averages (still depending on x and y).
!
!  19-jun-02/axel: coded
!
      real, dimension (nnamexy,nx,ny) :: fsumxy
!
!  Communicate over all processors along z beams.
!  The result is only present on the z-root processors.
!
      if (nnamexy>0) then
        call mpireduce_sum(fnamexy,fsumxy,(/nnamexy,nx,ny/),idir=3)
        if (lfirst_proc_z) fnamexy=fsumxy/nzgrid
      endif
!
    endsubroutine zaverages_xy
!***********************************************************************
    subroutine phiaverages_rz()
!
!  Calculate azimuthal averages (as functions of r_cyl,z).
!  NOTE: these averages depend on (r and) z, so after summation they
!  are still distributed over nprocz CPUs; hence the dimensions of fsumrz
!  (and fnamerz).
!
!  9-dec-02/wolf: coded
!
      integer :: i
      real, dimension (nrcyl,0:nz,nprocz,nnamerz) :: fsumrz
!
!  Communicate over all processors.
!  The result is only present on the root processor
!  normalize by sum of unity which is accumulated in fnamerz(:,0,:,1).
!
      if (nnamerz>0) then
        call mpireduce_sum(fnamerz,fsumrz,(/nrcyl,nz+1,nprocz,nnamerz/))
        if (lroot) then
          do i=1,nnamerz
            fnamerz(:,1:nz,:,i)=fsumrz(:,1:nz,:,i)/spread(fsumrz(:,0,:,1),2,nz)
          enddo
        endif
      endif
!
    endsubroutine phiaverages_rz
!***********************************************************************
    subroutine write_1daverages()
!
!  Write 1d averages (z-averages, .., i.e. quantities that are only  1d
!  after averaging). These are written every it1d (default it1) timesteps
!  and appended to their individual files.
!
!   7-aug-03/wolf: coded
!
      call write_xyaverages()
      call write_xzaverages()
      call write_yzaverages()
      call write_phizaverages()
!
    endsubroutine write_1daverages
!***********************************************************************
    subroutine write_2daverages_prepare()
!
!  Prepare l2davg for writing 2D averages.
!  This needs to be done in the beginning of each time step, so
!  the various routines know that they need to calculate averages.
!
!  23-nov-03/axel: adapted from write_2daverages and wvid_prepare
!
      use Sub, only: update_snaptime, read_snaptime
!
      real, save :: t2davg
      integer, save :: n2davg
      logical, save :: first=.true.
      character (len=fnlen) :: file
!
      file=trim(datadir)//'/t2davg.dat'
      if (first) then
        call read_snaptime(trim(file),t2davg,n2davg,d2davg,t)
      endif
      first = .false.
!
!  This routine sets l2davg=T whenever its time to write 2D averages
!
      call update_snaptime(file,t2davg,n2davg,d2davg,t,l2davg,ch2davg)
!
    endsubroutine write_2daverages_prepare
!***********************************************************************
    subroutine write_2daverages()
!
!  Write 2d averages (z-averages, phi-averages, .., i.e. quantities that
!  are still 2d after averaging) if it is time.
!  In analogy to 3d output to VARN, the time interval between two writes
!  is determined by a parameter (t2davg) in run.in.
!
!   7-aug-03/wolf: adapted from wsnap
!
      if (lwrite_yaverages)   call write_yaverages()
      if (lwrite_zaverages)   call write_zaverages()
      if (lwrite_phiaverages) call write_phiaverages(ch2davg)
!
      if (ip<=10) write(*,*) 'write_2daverages: wrote phi(etc.)avgs'//ch2davg
!
    endsubroutine write_2daverages
!***********************************************************************
    subroutine write_xyaverages()
!
!  Write xy-averages (which are 1d data) that have been requested via
!  `xyaver.in'
!
!   6-jun-02/axel: coded
!
      integer :: iostat
      character(LEN=linelen) :: iomsg
      logical :: lop
!
      if (lroot.and.nnamez>0) then
!
        inquire(1,opened=lop)
        if (.not.lop) then
          open(1,file=trim(datadir)//'/xyaverages.dat',position='append',IOSTAT=iostat,iomsg=iomsg)
! file not distributed, backskipping enabled
          if (outlog(iostat,'openw',trim(datadir)//'/xyaverages.dat',dist=-1, &
                     location='write_xyaverages',iomsg=iomsg)) return
        endif
!
        write(1,'(1pe12.5)',IOSTAT=iostat,iomsg=iomsg) t1ddiagnos
        if (outlog(iostat,'t1ddiagnos',iomsg=iomsg)) return
!
        write(1,'(1p,8e14.5e3)',IOSTAT=iostat,iomsg=iomsg) fnamez(:,:,1:nnamez)
        if (outlog(iostat,'fnamez',iomsg=iomsg)) return
!
        close(1,IOSTAT=iostat,iomsg=iomsg)
        if (outlog(iostat,'close',iomsg=iomsg)) continue
!
      endif
!
    endsubroutine write_xyaverages
!***********************************************************************
    subroutine write_xzaverages()
!
!  Write xz-averages (which are 1d data) that have been requested via
!  `xzaver.in'
!
!  12-oct-05/anders: adapted from write_xyaverages
!
      integer :: iostat
      character(LEN=linelen) :: iomsg
!
      if (lroot.and.nnamey>0) then
!
        open(1,file=trim(datadir)//'/xzaverages.dat',position='append',IOSTAT=iostat,iomsg=iomsg)
! file not distributed, backskipping enabled
        if (outlog(iostat,'openw',trim(datadir)//'/xzaverages.dat',dist=-1, &
                   location='write_xzaverages',iomsg=iomsg)) return
!
        write(1,'(1pe12.5)',IOSTAT=iostat,iomsg=iomsg) t1ddiagnos
        if (outlog(iostat,'t1ddiagnos',iomsg=iomsg)) return
!
        write(1,'(1p,8e14.5e3)',IOSTAT=iostat,iomsg=iomsg) fnamey(:,:,1:nnamey)
        if (outlog(iostat,'fnamey',iomsg=iomsg)) return
!
        close(1,IOSTAT=iostat,iomsg=iomsg)
        if (outlog(iostat,'close',iomsg=iomsg)) continue
!
      endif
!
    endsubroutine write_xzaverages
!***********************************************************************
    subroutine write_yzaverages()
!
!  Write yz-averages (which are 1d data) that have been requested via
!  `yzaver.in'
!
!   2-oct-05/anders: adapted from write_xyaverages
!
      integer :: iostat
      character(LEN=linelen) :: iomsg
!
      if (lroot.and.nnamex>0) then
!
        open(1,file=trim(datadir)//'/yzaverages.dat',position='append',IOSTAT=iostat,iomsg=iomsg)
! file not distributed, backskipping enabled
        if (outlog(iostat,'openw',trim(datadir)//'/yzaverages.dat',dist=-1, &
                   location='write_yzaverages',iomsg=iomsg)) return
!
        write(1,'(1pe12.5)',IOSTAT=iostat,iomsg=iomsg) t1ddiagnos
        if (outlog(iostat,'t1ddiagnos',iomsg=iomsg)) return
!
        write(1,'(1p,8e14.5e3)',IOSTAT=iostat,iomsg=iomsg) fnamex(:,:,1:nnamex)
        if (outlog(iostat,'fnamex',iomsg=iomsg)) return
!
        close(1,IOSTAT=iostat,iomsg=iomsg)
        if (outlog(iostat,'close',iomsg=iomsg)) continue
!
      endif
!
    endsubroutine write_yzaverages
!***********************************************************************
    subroutine write_phizaverages()
!
!  Write phiz-averages (which are 1d data) that have been requested via
!  `phizaver.in'
!
!  Also write rcyl to the output. It is needed just once, since it will
!  not change over the simulation. The condition "if (it==1)" is not the
!  best one, since it is reset upon restarting of a simulation and
!  therefore one has to manually remove the extra(s) rcyl from
!  the phizaverages.dat file
!
!  29-jan-07/wlad: adapted from write_yzaverages
!
      integer :: iostat
      character(LEN=linelen) :: iomsg
!
      if (lroot.and.nnamer>0) then
!
        open(1,file=trim(datadir)//'/phizaverages.dat',position='append',IOSTAT=iostat,iomsg=iomsg)
! file not distributed, backskipping enabled
        if (outlog(iostat,'openw',trim(datadir)//'/phizaverages.dat',dist=-1, &
                   location='write_phizaverages',iomsg=iomsg)) return
!
        if (it==1) then     ! right question?
          write(1,'(1p,8e14.5e3)',IOSTAT=iostat,iomsg=iomsg) rcyl
          if (outlog(iostat,'rcyl',iomsg=iomsg)) return
        endif
!
        write(1,'(1pe12.5)',IOSTAT=iostat,iomsg=iomsg) t1ddiagnos
        if (outlog(iostat,'t1ddiagnos',iomsg=iomsg)) return
!
        write(1,'(1p,8e14.5e3)',IOSTAT=iostat,iomsg=iomsg) fnamer(:,1:nnamer)
        if (outlog(iostat,'fnamer',iomsg=iomsg)) return
!
        close(1,IOSTAT=iostat,iomsg=iomsg)
        if (outlog(iostat,'close',iomsg=iomsg)) continue
!
      endif
!
    endsubroutine write_phizaverages
!***********************************************************************
    subroutine write_yaverages()
!
!  Write y-averages (which are 2d data) that have been requested via yaver.in.
!
!   7-jun-05/axel: adapted from write_zaverages
!
      integer :: iostat
      character(LEN=linelen) :: iomsg
!
      if (lfirst_proc_y.and.nnamexz>0) then
        open(1, file=trim(directory_dist)//'/yaverages.dat', &
            form='unformatted', position='append',IOSTAT=iostat,iomsg=iomsg)
! file distributed, backskipping enabled
        if (outlog(iostat,'openw',trim(directory_dist)//'/yaverages.dat',dist=1, &
                   location='write_yaverages',iomsg=iomsg)) return
!
        write(1,IOSTAT=iostat,iomsg=iomsg) t2davgfirst
        if (outlog(iostat,'t2davgfirst',iomsg=iomsg)) return
!
        write(1,IOSTAT=iostat,iomsg=iomsg) fnamexz(:,:,1:nnamexz)
        if (outlog(iostat,'fnamexz',iomsg=iomsg)) return
!
        close(1,IOSTAT=iostat,iomsg=iomsg)
        if (outlog(iostat,'close',iomsg=iomsg)) continue
!
      endif
!
    endsubroutine write_yaverages
!***********************************************************************
    subroutine write_zaverages()
!
!  Write z-averages (which are 2d data) that have been requested via zaver.in.
!
!  19-jun-02/axel: adapted from write_xyaverages
!
      integer :: iostat, i
      character(LEN=linelen) :: iomsg
!
      if (lfirst_proc_z.and.nnamexy>0) then
        open(1, file=trim(directory_dist)//'/zaverages.dat', &
            form='unformatted', position='append',IOSTAT=iostat,iomsg=iomsg)
! file distributed, backskipping enabled
        if (outlog(iostat,'openw',trim(directory_dist)//'/zaverages.dat',dist=1, &
                   location='write_zaverages',iomsg=iomsg)) return
!
        write(1,IOSTAT=iostat,iomsg=iomsg) t2davgfirst
        if (outlog(iostat,'t2davgfirst',iomsg=iomsg)) return
!
        write(1,IOSTAT=iostat,iomsg=iomsg) (fnamexy(i,:,:),i=1,nnamexy)
        if (outlog(iostat,'fnamexy',iomsg=iomsg)) return
!
        close(1,IOSTAT=iostat,iomsg=iomsg)
        if (outlog(iostat,'close',iomsg=iomsg)) continue
!
      endif
!
    endsubroutine write_zaverages
!***********************************************************************
    subroutine write_phiaverages_file(ch)
!
!  File format:
!    1. nr_phiavg, nz_phiavg, nvars, nprocz
!    2. t, r_phiavg, z_phiavg, dr, dz
!    3. data
!    4. len(labels),labels
!
!   27-Nov-2014/Bourdin.KIS: cleaned up code from write_phiaverages
!
      use General, only: safe_character_append
!
      character(len=*), intent(in) :: ch
!
      integer, parameter :: lun=1
      integer :: i,iostat
      character(LEN=linelen) :: iomsg
      character (len=1024) :: labels
!
      open(lun,FILE=trim(datadir)//'/averages/PHIAVG'//trim(ch),FORM='unformatted',IOSTAT=iostat,iomsg=iomsg)
      if (outlog(iostat,'openw',trim(datadir)//'/averages/PHIAVG'//trim(ch), &
                 location='write_phiaverages_file',iomsg=iomsg)) return
!
      write(lun,IOSTAT=iostat,iomsg=iomsg) nrcyl,nzgrid,nnamerz,nprocz
      if (outlog(iostat,'nrcyl etc.',iomsg=iomsg)) return
!
      write(lun,IOSTAT=iostat,iomsg=iomsg) t2davgfirst,rcyl,z(n1)+(/(i*dz, i=0,nzgrid-1)/),drcyl,dz
      if (outlog(iostat,'t2davgfirst etc.',iomsg=iomsg)) return
!
      !ngrs: use pack to explicitly order the array before writing
      !     (write was messing up on copson without this...)
!
      write(lun,IOSTAT=iostat,iomsg=iomsg) pack(fnamerz(:,1:nz,:,1:nnamerz),.true.)
      if (outlog(iostat,'fnamerz',iomsg=iomsg)) return
!
!  Write labels at the end of file.
!
      labels = trim(cnamerz(1))
      do i=2,nnamerz
        call safe_character_append(labels,",",trim(cnamerz(i)))
      enddo
      write(lun,IOSTAT=iostat,iomsg=iomsg) len(labels),labels
      if (outlog(iostat,'labels',iomsg=iomsg)) return
!
      close(lun,IOSTAT=iostat,iomsg=iomsg)
      if (outlog(iostat,'close',iomsg=iomsg)) continue
!
    endsubroutine write_phiaverages_file
!***********************************************************************
    subroutine write_phiaverages(ch)
!
!  Write azimuthal averages (which are 2d data) that have been requested
!  via `phiaver.in'.
!  Note: fnamerz still has a third dimension indicating ipz, but the way
!  we are writing we automatically end up with the full z-direction
!  written contiguously.
!
!   2-jan-03/wolf: adapted from write_zaverages
!
      character(len=*), intent(in) :: ch
!
      integer, parameter :: lun=1
      integer :: iostat
      character(LEN=linelen) :: iomsg
!
      if (.not. lroot .or. (nnamerz <= 0)) return
!
!  Write result; normalization is already done in phiaverages_rz.
!
      call write_phiaverages_file(ch)
!
!  Write file name to file list.
!
      open(lun,FILE=trim(datadir)//'/averages/phiavg.files',POSITION='append',IOSTAT=iostat,iomsg=iomsg)
      ! file not distributed, backskipping enabled
      if (outlog(iostat,'openw',trim(datadir)//'/averages/phiavg.files',dist=-1, &
                 location='write_phiaverages',iomsg=iomsg)) return
!
      write(lun,'(A)',IOSTAT=iostat,iomsg=iomsg)'PHIAVG'//trim(ch)
      if (outlog(iostat,'"PHIAVG"',iomsg=iomsg)) return
!
      close(lun,IOSTAT=iostat,iomsg=iomsg)
      if (outlog(iostat,'close',iomsg=iomsg)) continue
!
    endsubroutine write_phiaverages
!***********************************************************************
    integer function fparse_name(iname,cname,cform,ctest,itest)
!
!  Parse name and format of scalar print variable
!  On output, ITEST is set to INAME if CNAME matches CTEST
!  and CFORM is set to the format given as default.
!  E.g. if CTEST='bmax' *i.e. we are testing input line CNAME for 'bmax',
!  CNAME='bmax' will be parsed to ITEST=INAME, CFORM='(1pe10.2)',
!  CNAME='bmax(G5.1)' to ITEST=INAME, CFORM='G5.1',
!  CNAME='brms' to ITEST=<unchanged, normally 0>, CFORM='(1pe10.2)'
!
!   return value is iname if ctest matches
!                   -1    if so and itest/=0 at call (indicates multiple
!                         occurrence of the same diagnostic in print.in
!                   0     if ctest does not match
!
!   4-may-02/axel: coded
!   6-apr-04/wolf: more liberate format reading
!  26-feb-13/MR  : prepared for ignoring multiple occurrences of
!                  diagnostics in print.in
!  26-aug-13/MR  : removed unneeded 0p setting in format, added handling of D formats
!  27-aug13/MR   : reinstated 0p
!
      use General, only: safe_character_assign
!
      character (len=*) :: cname,cform
      character (len=*) :: ctest
      integer :: iname,itest,iform0,iform1,iform2,length,index_i
!
      intent(in)    :: iname,cname,ctest
      intent(inout) :: itest
      intent(out)   :: cform
!
!  Check whether format is given.
!
      iform0=index(cname,' ')
      iform1=index(cname,'(')
      iform2=index(cname,')')
!
!  Set format; use default if not given.
!
      if (iform1>0) then
        cform=cname(iform1+1:iform2-1)
        length=iform1-1
      else
        cform='1pE10.2'  !!(the nag-f95 compiler requires a comma after
                         !! 1p [does it?])
        length=iform0-1
      endif
!
!  Fix annoying Fortran 1p stuff ([EDG]w.d --> 1p[EDG]w.d).
!
      if ((cform(1:1) == 'e') .or. (cform(1:1) == 'E') .or. &
          (cform(1:1) == 'd') .or. (cform(1:1) == 'D') .or. &
          (cform(1:1) == 'g') .or. (cform(1:1) == 'G'))     &
        call safe_character_assign(cform, '1p'//trim(cform)//',0p')
!
!  If the name matches, we keep the name and can strip off the format.
!  The remaining name can then be used for the legend.
!
      if (cname(1:length)==ctest) then
        if (itest==0) then
          itest=iname
          fparse_name=iname
        else
          fparse_name=-1
        endif
      else
        fparse_name=0
      endif
!
!  Integer formats are turned into floating point numbers.
!
      index_i=index(cform,'i')
      if (index_i==0) index_i=index(cform,'I')

      if (index_i/=0) then
        cform(index_i:index_i)='f'
        cform=trim(cform)//'.0'
      endif
!
    endfunction fparse_name
!***********************************************************************
    subroutine parse_name_s(iname,cname,cform,ctest,itest)
!
!   subroutine wrapper around fparse_name function: ignores return value
!
!   26-nov-09/MR: coded
!
      character (len=*) :: cname,cform
      character (len=*) :: ctest
      integer :: iname,itest
!
      intent(in)  :: iname,cname,ctest
      intent(out) :: cform
      intent(inout) :: itest
!
      integer :: iret
!
      iret = fparse_name(iname,cname,cform,ctest,itest)
!
    endsubroutine parse_name_s
!***********************************************************************
    subroutine parse_name_sa(iname,cname,cform,ctest,itest)
!
!   alternative form of parse_name_s: adopts full vectors for cname and cform
!
!   6-mar-13/MR: adapted from parse_name_s
!
      character (len=*), dimension(*) :: cname,cform
      character (len=*) :: ctest
      integer :: iname,itest
!
      intent(in)  :: iname,cname,ctest
      intent(out) :: cform
      intent(inout) :: itest
!
      integer :: iret
!
      iret = fparse_name(iname,cname(iname),cform(iname),ctest,itest)
!
    endsubroutine parse_name_sa
!***********************************************************************
    subroutine parse_name_v( cname,cform,cdiag,idiag )
!
!   extension to parse_name_s: cname, cform now vectors;
!                              names to look for now in vector cdiag,
!                              indices for found ones in vector idiag
!                              both do loops incorporated
!
!   29-jun-12/MR: coded
!
      character (len=*), dimension(:) :: cname,cform
      character (len=*), dimension(:) :: cdiag
      integer,           dimension(:) :: idiag
!
      intent(in)  :: cname,cdiag
      intent(out) :: cform,idiag
!
      integer :: i,j
!
      do i=1,size(cname)
        do j=1,size(cdiag)
          if ( fparse_name(i,cname(i),cform(i),cdiag(j),idiag(j)) /= 0 ) exit
        enddo
      enddo
!
    endsubroutine parse_name_v
!***********************************************************************
    subroutine expand_cname_short(ccname,nname,vlabel,vname,lform)
!
!  Expand string array cname with entries up to index nname such that,
!  if vlabel starts with <vname> or <vname><vname>, it is replaced by the three labels
!  <vname>x..., <vname>y..., <vname>z..., or correspondingly for curvilinear coord systems;
!  updates nname accordingly.
!
!  16-may-12/MR: coded
!
      character (len=*), dimension(:) :: ccname    ! F2003: , allocatable
      character (len=*) :: vlabel
      character (len=*) :: vname
      integer :: nname
      logical, optional :: lform
!
      intent(inout) :: ccname,nname
      intent(in) :: vlabel, vname, lform
!
      character (len=intlen):: tail,form
      integer :: ind, ic,lvn
!
      lvn = len(trim(vname))
      if (vlabel(1:lvn)/=trim(vname)) &
        call fatal_error('expand_cname_short','vlabel does not start with vname')
!
      if (present(lform)) then
        form='T'
      else
        form=''
      endif
!
      ic = name_is_present(ccname,trim(vlabel),form)
      if (ic>0) then
!
        ind=lvn+1
        if ( lvn==1 .and. vlabel(2:2)==vname ) ind=3
!
        tail=vlabel(ind:len(vlabel))
        if ( lspherical_coords ) then
          call expand_cname_full(ccname,nname,ic, &
                                 trim(vname)//'r'//trim(tail), &
                                 trim(vname)//'t'//trim(tail), &
                                 trim(vname)//'p'//trim(tail),form)
        elseif ( lcylindrical_coords ) then
          call expand_cname_full(ccname,nname,ic, &
                                 trim(vname)//'r'//trim(tail), &
                                 trim(vname)//'p'//trim(tail), &
                                 trim(vname)//'z'//trim(tail),form)
        else
          call expand_cname_full(ccname,nname,ic, &
                                 trim(vname)//'x'//trim(tail), &
                                 trim(vname)//'y'//trim(tail), &
                                 trim(vname)//'z'//trim(tail),form)
        endif
      endif
!
    endsubroutine expand_cname_short
!***********************************************************************
    subroutine expand_cname_full(ccname,nname,ic,xlabel,ylabel,zlabel,form)
!
!  Expand string array cname with entries up to index nname such that
!  label at position ic is replaced by the three labels xlabel, ylabel, zlabel;
!  update nname accordingly. Appends format form if present.
!
!   1-apr-04/wolf: coded
!  16-may-12/MR  : new parameters ic = position of label to be expanded in ccname and (optional)
!                  form for a format specification append to the name (for use with
!                  print.in
!
      use General, only : lextend_vector
!
      character (len=*), dimension(:) :: ccname   ! F2003: , allocatable
      character (len=*) :: xlabel,ylabel
      character (len=*), optional :: zlabel
      character (len=intlen), optional :: form
      integer :: nname,ic
!
      intent(inout) :: ccname,nname
      intent(in) :: xlabel,ylabel,zlabel,ic,form
!
      integer :: itot
      logical :: lform
!
      lform=present(form)
      if (lform) then
        if (form=='') lform=.false.
      endif
!
      if (ic<=0) return
!
      if (present(zlabel)) then
        itot=3
      else
        itot=2
      endif
!
      if (.not.lextend_vector(ccname,nname+itot-1)) & ! sanity check
        call fatal_error('expand_cname_full','Not enough memory')
!
      ccname(ic+itot:nname+itot-1) = ccname(ic+1:nname)
      if (lform) then
        ccname(ic) = xlabel//trim(form)
        ccname(ic+1) = ylabel//trim(form)
        if (present(zlabel)) ccname(ic+2) = zlabel//trim(form)
      else
        ccname(ic) = xlabel
        ccname(ic+1) = ylabel
        if (present(zlabel)) ccname(ic+2) = zlabel
      endif
!
      nname = nname+itot-1
!
    endsubroutine expand_cname_full
!***********************************************************************
    subroutine save_name(a,iname)
!
!  Lists the value of a (must be treated as real) in fname array
!
!  26-may-02/axel: adapted from max_mn_name
!
      real :: a
      integer :: iname
!
!  Set corresponding entry in itype_name
!  This routine is to be called only once per step
!
      if (iname/=0) then
        fname(iname)=a
        itype_name(iname)=ilabel_save
      endif
!
   endsubroutine save_name
!***********************************************************************
    subroutine save_name_sound(a,iname,iscoord)
!
!  Lists the value of a (must be treated as real) in fname array
!
!  3-Dec-10/dhruba+joern: adapted from max_mn_name
! 25-aug-13/MR: removed unneeded setting of itype, added test of iname.
!
      real :: a
      integer :: iname,iscoord
!
!  This routine is to be called only once per step
!
      if (iname/=0) fname_sound(iname,iscoord)=a
!
   endsubroutine save_name_sound
!***********************************************************************
    subroutine save_name_halfz(a,iname)
!
!  Lists the value of a (must be treated as real) in fname array
!
!  16-may-09/axel: adapted from save_name
!
      real, dimension(2) :: a
      integer :: iname
!
!  Set corresponding entry in itype_name
!  This routine is to be called only once per step
!
      fname_half(iname,1)=a(1)
      fname_half(iname,2)=a(2)
!
   endsubroutine save_name_halfz
!***********************************************************************
    subroutine max_name_int(a,iname,lneg)
!
!  Successively calculate maximum of a, which is supplied at each call.
!
!  29-aug-05/anders: adapted from save_name
!
      integer :: a, iname
      logical, optional :: lneg
!
      if (present(lneg)) then
        if (lneg) then
          if (a<fname(iname)) fname(iname)=a
        else
          if (a>fname(iname)) fname(iname)=a
        endif
      else
        if (a>fname(iname)) fname(iname)=a
      endif
!
!  Set corresponding entry in itype_name.
!
      if (present(lneg)) then
        itype_name(iname)=ilabel_max_neg
      else
        itype_name(iname)=ilabel_max
      endif
!
    endsubroutine max_name_int
!***********************************************************************
    subroutine max_name_real(a,iname,lneg,l_dt)
!
!  Successively calculate maximum of a, which is supplied at each call.
!
!  13-dec-10/ccyang: adapted from max_name
!
      real, intent(in) :: a
      integer, intent(in) :: iname
      logical, intent(in), optional :: lneg, l_dt
!
      if (present(lneg)) then
        if (lneg) then
          if (a<fname(iname)) fname(iname)=a
        else
          if (a>fname(iname)) fname(iname)=a
        endif
      else
        if (a>fname(iname)) fname(iname)=a
      endif
!
!  Set corresponding entry in itype_name.
!
      if (present(lneg)) then
        itype_name(iname)=ilabel_max_neg
      elseif (present(l_dt)) then
        itype_name(iname)=ilabel_max_dt
      else
        itype_name(iname)=ilabel_max
      endif
!
    endsubroutine max_name_real
!***********************************************************************
    subroutine sum_name(a,iname)
!
!  Calculate the summation of a, which is supplied at each call.
!
!  19-jun-11/anders: changed to sum single number of all cores
!  17-jun-09/ccyang: adapted from max_name
!  03-sep-09/MR: corrected to real sum
!
      real, intent(in) :: a
      integer, intent(in) :: iname
!
      fname(iname)=a
!
!  Set corresponding entry in itype_name.
!  Need to set ilabel_surf to avoid multiplication by volume later (to fix).
!
      itype_name(iname)=ilabel_surf
!
    endsubroutine sum_name
!***********************************************************************
    subroutine max_mn_name(a,iname,lsqrt,l_dt,lneg,lreciprocal)
!
!  Successively calculate maximum of a, which is supplied at each call.
!  Start from zero if lfirstpoint=.true.
!
!   1-apr-01/axel+wolf: coded
!   4-may-02/axel: adapted for fname array
!  23-jun-02/axel: allows for taking square root in the end
!  29-jun-12/MR: incorporated test for iname/=0
!
      real, dimension (nx) :: a
      integer :: iname
      logical, optional :: lsqrt,l_dt,lneg,lreciprocal
!
      if (iname==0) return
!
      if (lfirstpoint) then
        fname(iname)=maxval(a)
      else
        fname(iname)=max(fname(iname),maxval(a))
      endif
!
!  Set corresponding entry in itype_name.
!
      if (present(lsqrt)) then
        itype_name(iname)=ilabel_max_sqrt
      elseif (present(l_dt)) then
        itype_name(iname)=ilabel_max_dt
      elseif (present(lneg)) then
        itype_name(iname)=ilabel_max_neg
      elseif (present(lreciprocal)) then
        itype_name(iname)=ilabel_max_reciprocal
      else
        itype_name(iname)=ilabel_max
      endif
!
    endsubroutine max_mn_name
!***********************************************************************
    subroutine sum_mn_name_arr2(a,iname,lsqrt,lint,ipart)
!
!  20-aug-13/MR: derived from sum_mn_name; behaves as before if extent of
!                first dimension of a is 1; if it is 2 considers a a complex
!                pencil - stores real(imaginary) part in fname(fname_keep),
!                sets type of diagnostic to complex
!
      real, dimension(:,:), intent(IN) :: a
      integer,              intent(IN) :: iname
      integer, optional,    intent(IN) :: ipart
      logical, optional,    intent(IN) :: lsqrt, lint

      if (size(a,1)==1) then
        call sum_mn_name_std(a(1,:),iname,lsqrt,lint,ipart)
      else

        call sum_mn_name_real(a(1,:),iname,fname,lsqrt,lint,ipart)
        call sum_mn_name_real(a(2,:),iname,fname_keep)
        itype_name(iname)=itype_name(iname)+ilabel_complex

      endif
!
    endsubroutine sum_mn_name_arr2
!***********************************************************************
    subroutine sum_mn_name_std(a,iname,lsqrt,lint,ipart)
!
!  20-aug-13/MR: derived from sum_mn_name, behaves as before
!
      use Cdata, only: fname
!
      real, dimension(nx), intent(IN) :: a
      integer,             intent(IN) :: iname
      integer, optional,   intent(IN) :: ipart
      logical, optional,   intent(IN) :: lsqrt, lint

      call sum_mn_name_real(a,iname,fname,lsqrt,lint,ipart)

    endsubroutine sum_mn_name_std
!***********************************************************************
    subroutine sum_mn_name_real(a,iname,fname,lsqrt,lint,ipart)
!
!  Successively calculate sum of a, which is supplied at each call.
!  In subroutine 'diagnostic', the mean is calculated; if 'lint' is
!  explicitly given and true, the integral is calculated, instead.
!  With 'lsqrt=.true.', a square root is applied after building the mean.
!  Start from zero if lfirstpoint=.true.
!  TODO: for nonperiodic arrays we want to multiply boundary data by 1/2.
!  TODO: rename 'ilabel_sum{_sqrt}' as 'ilabel_mean{_sqrt}'.
!
!   1-apr-01/axel+wolf: coded
!   4-may-02/axel: adapted for fname array
!  23-jun-02/axel: allows for taking square root in the end
!  20-jun-07/dhruba: adapted for spherical polar coordinate system
!  30-aug-07/wlad: adapted for cylindrical coordinates
!  22-mar-08/axel: added ladd option, to add to previous values
!  29-aug-11/Bourdin.KIS: added TODO and a comment about building the mean
!  20-aug-13/MR: derived from sum_mn_name, made array of values fname a dummy argument
!  31-mar-15/MR: added switch for proper volume averaging
!
!  Note [24-may-2004, wd]:
!    This routine should incorporate a test for iname /= 0, so instead of
!         if (idiag_b2m/=0)    call sum_mn_name(b2,idiag_b2m)
!    we can just use
!         call sum_mn_name(b2,idiag_b2m)
!  Same holds for similar routines.
!  Update [28-Sep-2004 wd]:
!    Done here, but not yet in all other routines
!
      real, dimension(nx) :: a,a_scaled
      real, dimension(nname) :: fname
!
      real :: ppart,qpart
      integer :: iname
      integer, optional :: ipart
      logical, optional :: lsqrt, lint
!
      intent(in) :: iname
!
!  Only do something if iname is not zero.
!
      if (iname/=0) then
!
!  Set corresponding entry in itype_name.
!
        if (present(lsqrt)) then
          itype_name(iname)=ilabel_sum_sqrt
        elseif (present(lint)) then
          itype_name(iname)=ilabel_integrate
        else
          itype_name(iname)=ilabel_sum
        endif
!
!  Set fraction if old and new stuff.
!
        if (present(ipart)) then
          ppart=1./real(ipart)
          if (lfirstpoint) then
            qpart=1.-ppart
          else
            qpart=1.
          endif
!
!  Add up contributions, taking coordinate system into acount (particles).
!
          if (lspherical_coords) then
            fname(iname)=qpart*fname(iname)+ppart*sum(r2_weight*sinth_weight(m)*a)
          elseif (lcylindrical_coords) then
            fname(iname)=qpart*fname(iname)+ppart*sum(rcyl_weight*a)
          else
            fname(iname)=qpart*fname(iname)+ppart*sum(a)
          endif
!
!  Normal method.
!
        else

          if (lproper_averages) then
            call integrate_mn(a,fname(iname))
          else
!
!  Scale "a" with volume differential if integration option is set.
!
            if (present(lint)) then
              a_scaled=a*xprim(l1:l2)*yprim(m)*zprim(n)
            else
              a_scaled=a
            endif
!
!  Add up contributions, taking coordinate system into acount (fluid).
!  Initialize if one is on the first point, or add up otherwise.
!
            if (lfirstpoint) then
              if (lspherical_coords) then
                fname(iname)=sum(r2_weight*a_scaled)*sinth_weight(m)
              elseif (lcylindrical_coords) then
                fname(iname)=sum(rcyl_weight*a_scaled)
              else
                fname(iname)=sum(a_scaled)
              endif
            else
              if (lspherical_coords) then
                fname(iname)=fname(iname)+sum(r2_weight*a_scaled)*sinth_weight(m)
              elseif (lcylindrical_coords) then
                fname(iname)=fname(iname)+sum(rcyl_weight*a_scaled)
              else
                fname(iname)=fname(iname)+sum(a_scaled)
              endif
            endif
          endif
        endif
      endif
!
    endsubroutine sum_mn_name_real
!***********************************************************************
    subroutine sum_mn_name_halfy(a,iname)
!
!  To calculate averages over half the size of box, useful for simulations
!  which includes equator (either cartesian or spherical).
!
!  ??-???-??/dhruba: aped from sum_mn_name
!
      real, dimension (nx) :: a
      real :: sum_name
      integer :: iname
!
      if (iname /= 0) then
        sum_name=0
!
        if (y(m)>=yequator)then
          sum_name=fname_half(iname,2)
        else
          sum_name=fname_half(iname,1)
        endif
!
        if (lfirstpoint) then
          fname_half(iname,1)=0
          fname_half(iname,2)=0
          sum_name=0
          if (lspherical_coords) then
            sum_name=sum(r2_weight*sinth_weight(m)*a)
          elseif (lcylindrical_coords) then
            sum_name=sum(rcyl_weight*a)
          else
            sum_name=sum(a)
          endif
        else
          if (lspherical_coords) then
            sum_name=sum_name+sum(r2_weight*sinth_weight(m)*a)
          elseif (lcylindrical_coords) then
            sum_name=sum_name+sum(rcyl_weight*a)
          else
            sum_name=sum_name+sum(a)
          endif
        endif
!
        if (y(m)>=yequator)then
          fname_half(iname,2)=sum_name
        else
          fname_half(iname,1)=sum_name
        endif
!
      endif
!
    endsubroutine sum_mn_name_halfy
!***********************************************************************
    subroutine sum_mn_name_halfz(a,iname)
!
! To calculate averages over half the size of box (this time divided along the z
! direction), useful for simulations which includes equator (either cartesian
! or spherical).
!
!  7-may-09/dhruba: aped from sum_mn_name_halfy
!
      real, dimension (nx) :: a
      real :: sum_name
      integer :: iname
!
      if (iname /= 0) then
        sum_name=0
!
!  Note: north means 1 and south means 2.
!  However, north corresponds to z < zequator,
!  in analogy to theta < !pi/2 for north.
!
        if (z(n)>=zequator) then
          sum_name=fname_half(iname,2)
        else
          sum_name=fname_half(iname,1)
        endif
!
        if (lfirstpoint) then
          fname_half(iname,1)=0
          fname_half(iname,2)=0
          sum_name=0
          if (lspherical_coords) then
            sum_name=sum(r2_weight*sinth_weight(m)*a)
          elseif (lcylindrical_coords) then
            sum_name=sum(rcyl_weight*a)
          else
            sum_name=sum(a)
          endif
        else
          if (lspherical_coords) then
            sum_name=sum_name+sum(r2_weight*sinth_weight(m)*a)
          elseif (lcylindrical_coords) then
            sum_name=sum_name+sum(rcyl_weight*a)
          else
            sum_name=sum_name+sum(a)
          endif
        endif
!
!  North means 1 and south means 2.
!  However, north corresponds to z < zequator,
!  in analogy to theta < !pi/2 for north.
!
        if (z(n)>=zequator) then
          fname_half(iname,2)=sum_name
        else
          fname_half(iname,1)=sum_name
        endif
!
      endif
!
    endsubroutine sum_mn_name_halfz
!***********************************************************************
    subroutine sum_weighted_name(a,weight,iname,lsqrt)
!
!  Succesively calculate the weighted sum of a. The result is divided by the
!  total weight in the diagnostics subroutine.
!
!  17-apr-06/anders: coded
!
      real, dimension (:) :: a, weight
      integer :: iname
      logical, optional :: lsqrt
!
      integer, save :: it_save=-1, itsub_save=-1
!
!  Only do something if iname is not zero.
!
      if (iname/=0) then
!
        if (it/=it_save .or. itsub/=itsub_save) then
          fname(iname)=0.0
          fweight(iname)=0.0
          it_save=it
          itsub_save=itsub
        endif
!
        fname(iname)  =fname(iname)  +sum(weight*a)
        fweight(iname)=fweight(iname)+sum(weight)
!
!  Set corresponding entry in itype_name.
!
        if (present(lsqrt)) then
          itype_name(iname)=ilabel_sum_weighted_sqrt
        else
          itype_name(iname)=ilabel_sum_weighted
        endif
!
      endif
!
    endsubroutine sum_weighted_name
!***********************************************************************
    subroutine sum_lim_mn_name(a,iname,p)
!
!  Successively calculate integral of a, which is supplied at each call.
!  Just takes values between r_int < r < r_ext
!  The purpose is to compute quantities just inside a cylinder or sphere
!
!   2-nov-05/wlad: adapted from sum_mn_name
!
      real, dimension (nx) :: a,aux,rlim
      type (pencil_case) :: p
      real :: dv
      integer :: iname,i,isum
!
      if (iname /= 0) then
!
        if (lcylinder_in_a_box) then
          rlim=p%rcyl_mn
        elseif (lsphere_in_a_box) then
          rlim=p%r_mn
        else
          call warning("sum_lim_mn_name","no reason to call it if you are "//&
               "not using a cylinder or a sphere embedded in a "//&
               "Cartesian grid")
        endif
!
         dv=1.
         if (nxgrid/=1) dv=dv*dx
         if (nygrid/=1) dv=dv*dy
         if (nzgrid/=1) dv=dv*dz
!
         do i=1,nx
            if ((rlim(i) <= r_ext).and.(rlim(i) >= r_int)) then
               aux(i) = a(i)
            else
               aux(i) = 0.
            endif
         enddo
!
         if (lfirstpoint) then
            if (lspherical_coords)then
              fname(iname) = 0.
              do isum=l1,l2
                fname(iname)=fname(iname)+ &
                        x(isum)*x(isum)*sinth(m)*aux(isum-nghost)*dv
              enddo
            else
              fname(iname)=sum(aux)*dv
            endif
         else
            if (lspherical_coords)then
              do isum=l1,l2
                fname(iname)=fname(iname)+ &
                      x(isum)*x(isum)*sinth(isum)*aux(isum-nghost)*dv
              enddo
            else
              fname(iname)=fname(iname)+sum(aux)*dv
            endif
         endif
!
         itype_name(iname)=ilabel_sum_lim
!
      endif
!
    endsubroutine sum_lim_mn_name
!*********************************************************
    subroutine surf_mn_name(a,iname)
!
!  Successively calculate surface integral. This routine assumes
!  that "a" contains the partial result for each pencil, so here
!  we just need to add up the contributions from all processors.
!  Start from zero if lfirstpoint=.true.
!
!  14-aug-03/axel: adapted from sum_mn_name
!  15-feb-13/MR: test of iname incorporated
!
      real, intent(in) :: a
      integer, intent(in) :: iname
!
      if (iname>0) then
!
        if (lfirstpoint) then
          fname(iname)=a
        else
          fname(iname)=fname(iname)+a
        endif
!
!  Set corresponding entry in itype_name.
!
        itype_name(iname)=ilabel_surf
!
      endif
!
    endsubroutine surf_mn_name
!***********************************************************************
    subroutine integrate_mn(a,inta)
!
!  Successively calculate sum of a, which is supplied at each call.
!  Start from zero if lfirstpoint=.true. ultimately multiply by dv
!  to get the integral.  This differs from sum_mn_name by the
!  setting of ilabel_integrate and hence in the behaviour in the final
!  step.
!
!  Note, for regular integration (uniform meshes) it is better
!  to use the usual sum_mn_name routine with lint=.true.
!
!   1-dec-09/dhruba+piyali:
!
      real, dimension (nx) :: a
      real :: inta
!
      intent(in) :: a
      intent(inout) :: inta
!
      real :: tmp
!
!  initialize by the volume element (which is different for different m and n)
!
      tmp=sum(a*dVol_x(l1:l2))*dVol_y(m)*dVol_z(n)
!
!  initialize if one is on the first point, or add up otherwise
!
      if (lfirstpoint) then
        inta=tmp
      else
        inta=inta+tmp
      endif
!
    endsubroutine integrate_mn
!***********************************************************************
    subroutine integrate_mn_name(a,iname)
!
!  Successively calculate sum of a, which is supplied at each call.
!  Start from zero if lfirstpoint=.true. ultimately multiply by dv
!  to get the integral.  This differs from sum_mn_name by the
!  setting of ilabel_integrate and hence in the behaviour in the final
!  step.
!
!  Note, for regular integration (uniform meshes) it is better
!  to use the usual sum_mn_name routine with lint=.true.
!
!   30-may-03/tony: adapted from sum_mn_name
!   13-nov-06/tony: modified to handle stretched mesh
!   31-mar-15/MR: use integrate_mn to avoid doubled code
!
      real, dimension (nx) :: a
      integer :: iname
!
      if (iname==0) return

      call integrate_mn(a,fname(iname))
!
!  set corresponding entry in itype_name
!
      itype_name(iname)=ilabel_integrate
!
    endsubroutine integrate_mn_name
!***********************************************************************
    subroutine xysum_mn_name_z(a,iname)
!
!   3-sep-13/MR: derived from xysum_mn_name_z
!
      use Cdata, only: n
!
      real, dimension(nx), intent(IN) :: a
      integer,             intent(IN) :: iname

      call xysum_mn_name_z_npar(a,n,iname)

    endsubroutine xysum_mn_name_z
!***********************************************************************
    subroutine xysum_mn_name_z_npar(a,n,iname)
!
!  Successively calculate sum over x,y of a, which is supplied at each call.
!  The result fnamez is z-dependent.
!  Start from zero if lfirstpoint=.true.
!
!   5-jun-02/axel: adapted from sum_mn_name
!   3-sep-13/MR: derived from xysum_mn_name_z, index n now parameter
!
      real, dimension(nx), intent(IN) :: a
      integer,             intent(IN) :: n,iname
!
      integer :: isum,lmax,nl
!
!  Only do something if iname is not zero.
!
      if (iname/=0) then
!
!  Initialize to zero, including other parts of the z-array
!  which are later merged with an mpi reduce command.
!
        if (lfirstpoint) fnamez(:,:,iname)=0.0
!
!  n starts with nghost+1=4, so the correct index is n-nghost
!
        lmax=l2; nl=n-nghost
        if (lav_smallx)  lmax=ixav_max
        if (.not.loutside_avg) then
          if (lspherical_coords.or.lcylindrical_coords)then
            do isum=l1,lmax
              fnamez(nl,ipz+1,iname)=fnamez(nl,ipz+1,iname)+ &
                                     x(isum)*a(isum-nghost)
            enddo
          else
            do isum=l1,lmax
              fnamez(nl,ipz+1,iname)=fnamez(nl,ipz+1,iname)+ &
                                     a(isum-nghost)
            enddo
          endif
        endif
      endif
!
    endsubroutine xysum_mn_name_z_npar
!***********************************************************************
    subroutine xzsum_mn_name_y(a,iname)
!
!   3-sep-13/MR: derived from xzsum_mn_name_y
!
      use Cdata, only: m
!
      real, dimension(nx), intent(IN) :: a
      integer,             intent(IN) :: iname

      call xzsum_mn_name_y_mpar(a,m,iname)

    endsubroutine xzsum_mn_name_y
!***********************************************************************
    subroutine xzsum_mn_name_y_mpar(a,m,iname)
!
!  Successively calculate sum over x,z of a, which is supplied at each call.
!  The result fnamey is y-dependent.
!  Start from zero if lfirstpoint=.true.
!
!  12-oct-05/anders: adapted from xysum_mn_name_z
!   3-sep-13/MR: derived from xzsum_mn_name_y, index m now parameter
!
      real, dimension (nx), intent(IN) :: a
      integer,              intent(IN) :: iname,m
!
      integer :: isum,lmax,ml
!
!  Only do something if iname is not zero.
!
      if (iname/=0) then
!
!  Initialize to zero, including other parts of the z-array
!  which are later merged with an mpi reduce command.
!
        if (lfirstpoint) fnamey(:,:,iname)=0.0
!
!  m starts with mghost+1=4, so the correct index is m-nghost.
!
        lmax=l2; ml=m-nghost
!
        if (lav_smallx) lmax=ixav_max
        if (.not.loutside_avg) then
          if (lspherical_coords.and.nxgrid>1)then
            do isum=l1,lmax
              fnamey(ml,ipy+1,iname)=fnamey(ml,ipy+1,iname)+ &
                                     x(isum)*sinth(m)*a(isum-nghost)
            enddo
          else ! also correct for cylindrical
            do isum=l1,lmax
              fnamey(ml,ipy+1,iname)=fnamey(ml,ipy+1,iname)+ &
                                     a(isum-nghost)
            enddo
          endif
        endif
      endif
!
    endsubroutine xzsum_mn_name_y_mpar
!***********************************************************************
    subroutine yzsum_mn_name_x(a,iname)
!
!   3-sep-13/MR: derived from yzsum_mn_name_x
!
      use Cdata, only: m
!
      real, dimension(nx), intent(IN) :: a
      integer,             intent(IN) :: iname

      call yzsum_mn_name_x_mpar(a,m,iname)

    endsubroutine yzsum_mn_name_x
!***********************************************************************
    subroutine yzsum_mn_name_x_mpar(a,m,iname)
!
!  Successively calculate sum over y,z of a, which is supplied at each call.
!  The result fnamex is x-dependent.
!  Start from zero if lfirstpoint=.true.
!
!   2-oct-05/anders: adapted from xysum_mn_name_z
!   3-sep-13/MR: derived from yzsum_mn_name_x, m now parameter
!
      real, dimension (nx), intent(IN) :: a
      integer,              intent(IN) :: iname,m
!
!  Only do something if iname is not zero.
!
      if (iname/=0) then
!
!  Initialize to zero.
!
        if (lfirstpoint) fnamex(:,:,iname)=0.0
!
!  Use different volume differentials for different coordinate systems.
!
        if (lspherical_coords) then
          fnamex(:,ipx+1,iname)=fnamex(:,ipx+1,iname)+x(l1:l2)**2*sinth(m)*a
        elseif (lcylindrical_coords) then
          fnamex(:,ipx+1,iname)=fnamex(:,ipx+1,iname)+x(l1:l2)*a
        else
          fnamex(:,ipx+1,iname)=fnamex(:,ipx+1,iname)+a
        endif
      endif
!
    endsubroutine yzsum_mn_name_x_mpar
!***********************************************************************
    subroutine xyintegrate_mn_name_z(a,iname)
!
!   Integrate over x and y. Apply trapezoidal rule properly in the case
!   of non-periodic boundaries.
!
!   18-jun-07/tobi: adapted from xysum_mn_name_z
!
      real, dimension (nx) :: a
      integer :: iname
      real :: fac,suma
      integer :: nl
!
      if (iname==0) return
!
!  Initialize to zero, including other parts of the z-array
!  which are later merged with an mpi reduce command.
!
      if (lfirstpoint) fnamez(:,:,iname) = 0.0
!
      fac=1.0
!
      if ((m==m1.and.lfirst_proc_y).or.(m==m2.and.llast_proc_y)) then
        if (.not.lperi(2)) fac = .5*fac
      endif
!
      if (lperi(1)) then
        suma = fac*sum(a)
      else
        suma = fac*(sum(a(2:nx-1))+.5*(a(1)+a(nx)))
      endif
!
!  n starts with nghost+1=4, so the correct index is n-nghost.
!
      nl=n-nghost
      fnamez(nl,ipz+1,iname) = fnamez(nl,ipz+1,iname) + suma
!
    endsubroutine xyintegrate_mn_name_z
!***********************************************************************
    subroutine xzintegrate_mn_name_y(a,iname)
!
!   Integrate over x and z. Apply trapezoidal rule properly in the case
!   of non-periodic boundaries.
!
!   18-jun-07/tobi: adapted from xzsum_mn_name_y
!
      real, dimension (nx) :: a
      integer :: iname
      real :: fac,suma
!
      if (iname==0) return
!
!  Initialize to zero, including other parts of the z-array
!  which are later merged with an mpi reduce command.
!
      if (lfirstpoint) fnamey(:,:,iname) = 0.
!
      fac = 1.
!
      if ((n==n1.and.lfirst_proc_z).or.(n==n2.and.llast_proc_z)) then
        if (.not.lperi(3)) fac = .5*fac
      endif
!
      if (lperi(1)) then
        suma = fac*sum(a)
      else
        suma = fac*(sum(a(2:nx-1))+.5*(a(1)+a(nx)))
      endif
!
!  m starts with mghost+1=4, so the correct index is m-nghost.
!
      fnamey(m-nghost,ipy+1,iname) = fnamey(m-nghost,ipy+1,iname) + suma
!
    endsubroutine xzintegrate_mn_name_y
!***********************************************************************
    subroutine yzintegrate_mn_name_x(a,iname)
!
!   Integrate over y and z. Apply trapezoidal rule properly in the case
!   of non-periodic boundaries.
!
!   18-jun-07/tobi: adapted from yzsum_mn_name_x
!
      real, dimension (nx) :: a
      integer :: iname
      real :: fac
!
      if (iname==0) return
!
!  Initialize to zero.
!
      if (lfirstpoint) fnamex(:,:,iname) = 0.0
!
      fac=1.0
!
      if ((m==m1.and.lfirst_proc_y).or.(m==m2.and.llast_proc_y)) then
        if (.not.lperi(2)) fac = .5*fac
      endif
!
      if ((n==n1.and.lfirst_proc_z).or.(n==n2.and.llast_proc_z)) then
        if (.not.lperi(3)) fac = .5*fac
      endif
!
      fnamex(:,ipx+1,iname) = fnamex(:,ipx+1,iname) + fac*a
!
    endsubroutine yzintegrate_mn_name_x
!***********************************************************************
    subroutine phizsum_mn_name_r(a,iname)
!
!  Successively calculate sum over phi,z of a, which is supplied at each call.
!  Start from zero if lfirstpoint=.true.
!  The fnamer array uses one of its slots in mnamer where we put ones and sum
!  them up in order to get the normalization correct.
!
!  29-jan-07/wlad: adapted from yzsum_mn_name_x and phisum_mn_name
!
      real, dimension (nx) :: a
      integer :: iname,ir,nnghost
!
      if (iname==0) return
!
      if (lfirstpoint) fnamer(:,iname)=0.
      if (lfirstpoint.and.iname==nnamer) fnamer(:,iname+1)=0.
!
      do ir=1,nrcyl
        fnamer(ir,iname) = fnamer(ir,iname) + sum(a*phiavg_profile(ir,:))
      enddo
!
!  Normalization factor, just needs to be done once.
!  As is it a z-average, multiply by nz afterwards.
!
      nnghost=n-nghost
      if ((iname==nnamer).and.(nnghost==1)) then
!  Check if an extra slot is available on fnamer.
        if (nnamer==mnamer) call fatal_error('phizsum_mn_name_r', &
            'no slot for phi-normalization. decrease nnamer')
!
        do ir=1,nrcyl
          fnamer(ir,iname+1)= &
              fnamer(ir,iname+1) + sum(1.*phiavg_profile(ir,:))*nz
        enddo
      endif
!
    endsubroutine phizsum_mn_name_r
!***********************************************************************
    subroutine ysum_mn_name_xz(a,iname)
!
!   3-sep-13/MR: derived from ysum_mn_name_xz
!
      use Cdata, only: n
!
      real, dimension(nx), intent(IN) :: a
      integer,             intent(IN) :: iname

      call ysum_mn_name_xz_npar(a,n,iname)

    endsubroutine ysum_mn_name_xz
!***********************************************************************
    subroutine ysum_mn_name_xz_npar(a,n,iname)
!
!  Successively calculate sum over y of a, which is supplied at each call.
!  The result fnamexz is xz-dependent.
!  Start from zero if lfirstpoint=.true.
!
!   7-jun-05/axel: adapted from zsum_mn_name_xy
!   3-sep-13/MR: derived from ysum_mn_name_xz, n now parameter
!
      real, dimension (nx), intent(IN) :: a
      integer,              intent(IN) :: iname,n
!
      integer :: nl
!
      if (iname==0) return
!
!  Initialize to zero, including other parts of the xz-array
!  which are later merged with an mpi reduce command.
!
      if (lfirstpoint) fnamexz(:,:,iname)=0.
!
!  n starts with nghost+1=4, so the correct index is n-nghost.
!
      nl=n-nghost
!
      if (lspherical_coords.or.lcylindrical_coords)then
        fnamexz(:,nl,iname) = fnamexz(:,nl,iname)+a*x(l1:l2)
      else
        fnamexz(:,nl,iname) = fnamexz(:,nl,iname)+a
      endif
!
    endsubroutine ysum_mn_name_xz_npar
!***********************************************************************
    subroutine zsum_mn_name_xy(a,iname,lint)
!
!  Successively calculate sum over z of a, which is supplied at each call.
!  The result fnamexy is xy-dependent.
!  Start from zero if lfirstpoint=.true.
!
!  19-jun-02/axel: adapted from xysum_mn_name
!  08-feb-12/ccyang: add option for integration
!   3-sep-13/MR: derived from zsum_mn_name_xy
!
      use General, only: loptest
      use Cdata,   only: n,m
!
      real, dimension(nx), intent(in) :: a
      integer,             intent(in) :: iname
      logical,   optional, intent(in) :: lint
!
      if (iname==0) return
!
!  Scale factor for integration
!
      if (loptest(lint)) then
        call zsum_mn_name_xy_mpar((real(nzgrid)*zprim(n))*a,m,iname)
      else
        call zsum_mn_name_xy_mpar(a,m,iname)
      endif
!
    endsubroutine zsum_mn_name_xy
!***********************************************************************
    subroutine zsum_mn_name_xy_mpar(a,m,iname)
!
!  Initialize to zero, including other parts of the xy-array
!  which are later merged with an mpi reduce command.
!
!   3-sep-13/MR: derived from zsum_mn_name_xy, m now parameter
!                no optional lint because of compiler error in g95 and gfortran
!                when using the subroutine as an actual parameter
!
      real, dimension(nx), intent(in) :: a
      integer,             intent(in) :: iname, m
!
      integer :: ml
!
      if (iname==0) return
!
      if (lfirstpoint) fnamexy(iname,:,:)=0.
!
!  m starts with nghost+1=4, so the correct index is m-nghost.
!
      ml=m-nghost
!
      fnamexy(iname,:,ml)=fnamexy(iname,:,ml)+a
!
    endsubroutine zsum_mn_name_xy_mpar
!***********************************************************************
    subroutine calc_phiavg_profile(p)
!
!  Calculate profile for phi-averaging for given pencil.
!
!   2-feb-03/wolf: coded
!
      type (pencil_case) :: p
      real :: r0,width
      integer :: ir
!
      intent(in) :: p
!
!  We use a quartic-Gaussian profile ~ exp(-r^4)
!
!      width = .5*drcyl
      width = .7*drcyl
      do ir=1,nrcyl
        r0 = rcyl(ir)
        phiavg_profile(ir,:) = exp(-0.5*((p%rcyl_mn-r0)/width)**4)
      enddo
!
      if (.not.(lcylinder_in_a_box.or.lsphere_in_a_box)) &
          call warning('calc_phiavg_profile', &
          'no reason to call it if you are '//&
          'not using a cylinder or a sphere embedded in a '//&
          'Cartesian grid')
!
    endsubroutine calc_phiavg_profile
!***********************************************************************
    subroutine phisum_mn_name_rz(a,iname)
!
!  Successively calculate sum over phi of a, which is supplied at each call.
!  Start from zero if lfirstpoint=.true.
!  The fnamerz array has one extra slice in z where we put ones and sum
!  them up in order to get the normalization correct.
!
!   2-feb-03/wolf: adapted from xysum_mn_name_z
!
      real, dimension (nx) :: a
      integer :: iname,n_nghost,ir
!
      if (iname == 0) then
!
!  Nothing to be done (this variable was never asked for)
!
      else
!
!  Initialize to zero, including other parts of the rz-array
!  which are later merged with an mpi reduce command.
!  At least the root processor needs to reset all ipz slots, as it uses
!  fnamerz(:,:,:,:) for the final averages to write [see
!  phiaverages_rz()]; so we better reset everything:
!      if (lfirstpoint) fnamerz(:,:,ipz+1,iname) = 0.
        if (lfirstpoint) fnamerz(:,:,:,iname) = 0.
!
!  n starts with nghost+1=4, so the correct index is n-nghost
!
        n_nghost=n-nghost
        do ir=1,nrcyl
          fnamerz(ir,n_nghost,ipz+1,iname) &
               = fnamerz(ir,n_nghost,ipz+1,iname) + sum(a*phiavg_profile(ir,:))
        enddo
!
!  sum up ones for normalization; store result in fnamerz(:,0,:,1)
!  Only do this for the first n, or we would sum up nz times too often
!
        if (iname==1 .and. n_nghost==1) then
          do ir=1,nrcyl
            fnamerz(ir,0,ipz+1,iname) &
                 = fnamerz(ir,0,ipz+1,iname) + sum(1.*phiavg_profile(ir,:))
          enddo
        endif
!
      endif
!
    endsubroutine phisum_mn_name_rz
!***********************************************************************
    real function get_from_fname(iname)
!
!   Gets value from fname.
!
!   30-oct-09/MR: coded
!
    integer, intent(in) :: iname
!
    if (iname<1.or.iname>nname) then
      call fatal_error('get_from_fname', 'index not in legal range')
      get_from_fname = 0
    endif
!
    get_from_fname = fname(iname)
!
    endfunction get_from_fname
!***********************************************************************
    subroutine allocate_sound(nnamel)
!
!  Allocate the variables needed for "sound".
!
!   3-Dec-10/dhruba+joern: coded
!   11-jan-11/MR: parameter nnamel added
!
      use File_io, only : parallel_open, parallel_close, parallel_unit, parallel_count_lines
      use General, only : itoa
      use Sub, only : location_in_proc
!
      integer, intent(in) :: nnamel
!
      character (LEN=*), parameter :: sound_coord_file = 'sound.coords'
      integer :: isound
      logical :: lval
      integer :: ierr, il
      integer :: mcoords_sound
      integer, allocatable, dimension (:,:) :: temp_sound_coords
      real    :: xsound, ysound, zsound
      integer :: lsound, msound, nsound
      character (LEN=80) :: line
!
!  Allocate and initialize to zero. Setting it to zero is only
!  necessary because of the pencil test, which doesn't compute these
!  averages, and only evaluates its output for special purposes
!  such as computing mean field energies in calc_bmz, for example,
!
      mcoords_sound = parallel_count_lines(sound_coord_file)
      allocate(temp_sound_coords(mcoords_sound,3),stat=ierr)
      if (ierr>0) call fatal_error('allocate_sound', &
            'Could not allocate memory for temp_sound_coords')
!
      ncoords_sound = 0
!
      call parallel_open(sound_coord_file)
!
      do isound=1,mcoords_sound
!
        select case (dimensionality)
        case (1); read(parallel_unit,*,iostat=ierr) xsound
        case (2); read(parallel_unit,*,iostat=ierr) xsound, ysound
        case (3); read(parallel_unit,*,iostat=ierr) xsound, ysound, zsound
        case default
        endselect
!
        if (ierr < 0) exit ! end-of-file
!
        if (ierr > 0) then
!          backspace parallel_unit
!          read (parallel_unit,*) line
!          if ((line(1:1) /= comment_char) .and. (line(1:1) /= '!')) then
            print*, 'allocate_sound - Warning: unreadable data in line '// &
                    trim(itoa(isound))//' of '//trim(sound_coord_file)//' !'
!          endif
          cycle
        endif
!
        if (location_in_proc(xsound,ysound,zsound,lsound,msound,nsound)) then
!
          lval = .true.
          do il = 1, ncoords_sound
            if ((temp_sound_coords(il,1) == lsound) .and. &
                (temp_sound_coords(il,2) == msound) .and. &
                (temp_sound_coords(il,3) == nsound) ) then
              lval = .false.
              exit
            endif
          enddo
!
          if (lval) then
            ncoords_sound = ncoords_sound + 1
            temp_sound_coords(ncoords_sound,1) = lsound
            temp_sound_coords(ncoords_sound,2) = msound
            temp_sound_coords(ncoords_sound,3) = nsound
          endif
        endif
      enddo
!
      call parallel_close(parallel_unit)
!
      lwrite_sound = ncoords_sound>0
      if (lwrite_sound) then
!
        if (.not. allocated(cname_sound)) then
          allocate(cname_sound(nnamel),stat=ierr)
          if (ierr>0) call fatal_error('allocate_sound', &
              'Could not allocate memory for cname_sound')
        endif
!
        if (.not. allocated(sound_coords_list)) then
          allocate(sound_coords_list(ncoords_sound,3),stat=ierr)
          if (ierr>0) call fatal_error('allocate_sound', &
              'Could not allocate memory for sound_coords_list')
        endif
        sound_coords_list = temp_sound_coords(1:ncoords_sound,:)
!
        if (.not. allocated(fname_sound)) then
          allocate(fname_sound(nnamel,ncoords_sound),stat=ierr)
          if (ierr>0) call fatal_error('allocate_sound', &
              'Could not allocate memory for fname_sound')
          if (ldebug) print*, 'allocate_sound: allocated memory for '// &
              'fname_sound  with nname_sound  =', nnamel
!
        endif
        fname_sound = 0.0
!
        if (.not. allocated(cform_sound)) then
          allocate(cform_sound(nnamel),stat=ierr)
          if (ierr>0) call fatal_error('allocate_sound', &
              'Could not allocate memory for cform_sound')
        endif
        cform_sound = ' '
!
      endif
!
!  Now deallocate the temporary memory.
!
      deallocate(temp_sound_coords)
!
    endsubroutine allocate_sound
!***********************************************************************
    subroutine sound_clean_up
!
!  Frees up the memory allocated for sound.
!
!  ??-???-??/dhruba: coded
!
      if (allocated(sound_coords_list)) deallocate(sound_coords_list)
      if (allocated(fname_sound)) deallocate(fname_sound)
      if (allocated(cname_sound)) deallocate(cname_sound)
      if (allocated(cform_sound)) deallocate(cform_sound)
!
    endsubroutine sound_clean_up
!***********************************************************************
    subroutine allocate_fnames(nnamel)
!
!  Allocate arrays needed for diagnostics.
!
!   23-mar-10/Bourdin.KIS: copied from allocate_yaverages
!   11-jan-11/MR: parameter nnamel added
!   18-aug-13/MR: accumulation of diagnostics enabled
!   25-aug-13/MR: added allocation of itype_name
!
      integer, intent(in) :: nnamel
!
      integer :: stat
!
      if (.not.allocated(cname)) then
        allocate(cname(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_fnames', &
            'Could not allocate memory for cname')
        if (ldebug) print*, 'allocate_fnames    : allocated memory for '// &
            'cname   with nname   =', nnamel
      endif
      cname=''
!
      if (.not.allocated(fname)) then
        allocate(fname(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_fnames', &
            'Could not allocate memory for fname')
        if (ldebug) print*, 'allocate_fnames    : allocated memory for '// &
            'fname   with nname   =', nnamel
        allocate(fname_keep(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_fnames', &
            'Could not allocate memory for fname_keep')
      endif
      fname=0.0
      fname_keep=0.0
!
      if (.not.allocated(cform)) then
        allocate(cform(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_fnames', &
            'Could not allocate memory for cform')
        if (ldebug) print*, 'allocate_fnames    : allocated memory for '// &
            'cform   with nname   =', nnamel
      endif
      cform=''
!
      if (.not.allocated(itype_name)) then
        allocate(itype_name(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_fnames', &
            'Could not allocate memory for itype_name')
        if (ldebug) print*, 'allocate_fnames    : allocated memory for '// &
            'itype_name with nname   =', nnamel
      endif
      itype_name=ilabel_save

    endsubroutine allocate_fnames
!***********************************************************************
    subroutine allocate_vnames(nnamel)
!
!  Allocate arrays needed for video slices.
!
!   23-mar-10/Bourdin.KIS: copied from allocate_yaverages
!   11-jan-11/MR: parameter nnamel added
!
      integer, intent(in) :: nnamel
!
      integer :: stat
!
      if (.not.allocated(cnamev)) then
        allocate(cnamev(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_vnames', &
            'Could not allocate memory for cnamev')
        if (ldebug) print*, 'allocate_vnames    : allocated memory for '// &
            'cnamev  with nnamev  =', nnamel
      endif
      cnamev=''
!
    endsubroutine allocate_vnames
!***********************************************************************
    subroutine allocate_xyaverages(nnamel)
!
!  Allocate arrays needed for xy-averages.
!
!   24-nov-09/anders: copied from allocate_yaverages
!   11-jan-11/MR: parameter nnamel added
!
      integer, intent(in) :: nnamel
!
      integer :: stat
!
!  Allocate and initialize to zero. Setting it to zero is only
!  necessary because of the pencil test, which doesn't compute these
!  averages, and only evaluates its output for special purposes
!  such as computing mean field energies in calc_bmz, for example,
!
      if (.not.allocated(cnamez)) then
        allocate(cnamez(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_xyaverages', &
            'Could not allocate memory for cnamez')
        if (ldebug) print*, 'allocate_xyaverages: allocated memory for '// &
            'cnamez  with nnamez  =', nnamel
      endif
      cnamez=''
!
      if (.not.allocated(fnamez)) then
        allocate(fnamez(nz,nprocz,nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_xyaverages', &
            'Could not allocate memory for fnamez')
        if (ldebug) print*, 'allocate_xyaverages: allocated memory for '// &
            'fnamez  with nnamez  =', nnamel
      endif
      fnamez=0.0
!
      if (.not.allocated(cformz)) then
        allocate(cformz(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_xyaverages', &
            'Could not allocate memory for cformz')
        if (ldebug) print*, 'allocate_xyaverages: allocated memory for '// &
            'cformz  with nnamez  =', nnamel
      endif
      cformz=''
!
    endsubroutine allocate_xyaverages
!***********************************************************************
    subroutine allocate_xzaverages(nnamel)
!
!  Allocate arrays needed for xz-averages.
!
!   24-nov-09/anders: copied from allocate_yaverages
!   11-jan-11/MR: parameter nnamel added
!
      integer, intent(in) :: nnamel
!
      integer :: stat
!
      if (.not.allocated(cnamey)) then
        allocate(cnamey(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_xzaverages', &
            'Could not allocate memory for cnamey')
        if (ldebug) print*, 'allocate_xzaverages: allocated memory for '// &
            'cnamey  with nnamey  =', nnamel
      endif
      cnamey=''
!
      if (.not.allocated(fnamey)) then
        allocate(fnamey(ny,nprocy,nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_xzaverages', &
            'Could not allocate memory for fnamey', .true.)
        if (ldebug) print*, 'allocate_xzaverages: allocated memory for '// &
            'fnamey  with nnamey  =', nnamel
      endif
      fnamey=0.0
!
      if (.not.allocated(cformy)) then
        allocate(cformy(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_xzaverages', &
            'Could not allocate memory for cformy', .true.)
        if (ldebug) print*, 'allocate_xzaverages: allocated memory for '// &
            'cformy  with nnamey  =', nnamel
      endif
      cformy=''
!
    endsubroutine allocate_xzaverages
!***********************************************************************
    subroutine allocate_yzaverages(nnamel)
!
!  Allocate arrays needed for yz-averages.
!
!   24-nov-09/anders: copied from allocate_yaverages
!   11-jan-11/MR: parameter nnamel added
!
      integer, intent(in) :: nnamel
!
      integer :: stat
!
      if (.not.allocated(cnamex)) then
        allocate(cnamex(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_yzaverages', &
            'Could not allocate memory for cnamex')
        if (ldebug) print*, 'allocate_yzaverages: allocated memory for '// &
            'cnamex  with nnamex  =', nnamel
      endif
      cnamex=''
!
      if (.not.allocated(fnamex)) then
        allocate(fnamex(nx,nprocx,nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_yzaverages', &
            'Could not allocate memory for fnamex')
        if (ldebug) print*, 'allocate_yzaverages: allocated memory for '// &
            'fnamex  with nnamex  =', nnamel
      endif
      fnamex=0.0
!
      if (.not.allocated(cformx)) then
        allocate(cformx(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_yzaverages', &
            'Could not allocate memory for cformx')
        if (ldebug) print*, 'allocate_yzaverages: allocated memory for '// &
            'cformx  with nnamex  =', nnamel
      endif
      cformx=''
!
    endsubroutine allocate_yzaverages
!***********************************************************************
    subroutine allocate_phizaverages(nnamel)
!
!  Allocate arrays needed for phiz-averages.
!
!   24-nov-09/anders: copied from allocate_yaverages
!   11-jan-11/MR: parameter nnamel added
!
      integer, intent(in) :: nnamel
!
      integer :: stat
!
      if (.not. allocated(cnamer)) then
        allocate(cnamer(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_phizaverages', &
            'Could not allocate memory for cnamer')
        if (ldebug) print*, 'allocate_phizaverages: allocated memory for '// &
            'cnamer  with nnamel =', nnamel
      endif
      cnamer=''
!
      mnamer=nnamel+1
      if (.not.allocated(fnamer)) then
        allocate(fnamer(nrcyl,mnamer),stat=stat)
        if (stat>0) call fatal_error('allocate_phizaverages', &
            'Could not allocate memory for fnamer')
        if (ldebug) print*, 'allocate_phizaverages: allocated memory for '// &
            'fnamer  with nnamer+1 =', mnamer
      endif
      fnamer=0.0
!
      if (.not.allocated(cformr)) then
        allocate(cformr(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_phizaverages', &
            'Could not allocate memory for cformr')
        if (ldebug) print*, 'allocate_phizaverages: allocated memory for '// &
            'cformr  with nnamel =', nnamel
      endif
      cformr=''
!
    endsubroutine allocate_phizaverages
!***********************************************************************
    subroutine allocate_yaverages(nnamel)
!
!  Allocate arrays needed for y-averages.
!
!   12-aug-09/dhruba: coded
!   11-jan-11/MR: parameter nnamel added
!
      integer, intent(in) :: nnamel
!
      integer :: stat
!
      if (.not.allocated(cnamexz)) then
        allocate(cnamexz(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_yaverages', &
            'Could not allocate memory for cnamexz')
        if (ldebug) print*, 'allocate_yaverages : allocated memory for '// &
            'cnamexz with nnamexz =', nnamel
      endif
      cnamexz=''
!
      if (.not.allocated(fnamexz)) then
        allocate(fnamexz(nx,nz,nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_yaverages', &
            'Could not allocate memory for fnamexz')
        if (ldebug) print*, 'allocate_yaverages : allocated memory for '// &
            'fnamexz with nnamexz =', nnamel
      endif
      fnamexz=0.0
!
      if (.not.allocated(cformxz)) then
        allocate(cformxz(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_yaverages', &
            'Could not allocate memory for cformxz')
        if (ldebug) print*, 'allocate_yaverages : allocated memory for '// &
            'cformxz with nnamexz =', nnamel
      endif
      cformxz=''
!
    endsubroutine allocate_yaverages
!*******************************************************************
    subroutine allocate_zaverages(nnamel)
!
!  Allocate arrays needed for z-averages.
!
!   12-aug-09/dhruba: coded
!   11-jan-11/MR: parameter nnamel added
!
      integer, intent(in) :: nnamel
!
      integer :: stat
!
      if (.not.allocated(cnamexy)) then
        allocate(cnamexy(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_zaverages', &
            'Could not allocate memory for cnamexy')
        if (ldebug) print*, 'allocate_zaverages : allocated memory for '// &
            'cnamexy with nnamexy =', nnamel
      endif
      cnamexy=''
!
      if (.not.allocated(fnamexy)) then
        allocate(fnamexy(nnamel,nx,ny),stat=stat)
        if (stat>0) call fatal_error('allocate_zaverages', &
            'Could not allocate memory for fnamexy')
        if (ldebug) print*, 'allocate_zaverages : allocated memory for '// &
            'fnamexy with nnamexy =', nnamel
      endif
      fnamexy=0.
!
      if (.not.allocated(cformxy)) then
        allocate(cformxy(nnamel),stat=stat)
        if (stat>0) &
          call fatal_error('allocate_zaverages', &
            'Could not allocate memory for cformxy')
        if (ldebug) print*, 'allocate_zaverages : allocated memory for '// &
            'fnamexy with cformxy =', nnamel
      endif
      cformxy=''
!
    endsubroutine allocate_zaverages
!*******************************************************************
    subroutine allocate_phiaverages(nnamel)
!
!  Allocate arrays needed for phi-averages.
!
!   24-nov-09/anders: copied from allocate_zaverages
!   11-jan-11/MR: parameter nnamel=iadd+nnamerz instead of nnamerz
!
      integer, intent(in) :: nnamel
!
      integer :: stat
!
      if (.not.allocated(cnamerz)) then
        allocate(cnamerz(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_phiaverages', &
            'Could not allocate memory for cnamerz')
        if (ldebug) print*, 'allocate_phiaverages : allocated memory for '// &
            'cnamerz with nnamerz =', nnamel
      endif
      cnamerz=''
!
      if (.not.allocated(fnamerz)) then
        allocate(fnamerz(nrcyl,0:nz,nprocz,nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_phiaverages', &
            'Could not allocate memory for fnamerz')
        if (ldebug) print*, 'allocate_phiaverages : allocated memory for '// &
            'fnamerz with nnamerz =', nnamel
      endif
      fnamerz=0.0
!
      if (.not.allocated(cformrz)) then
        allocate(cformrz(nnamel),stat=stat)
        if (stat>0) call fatal_error('allocate_phiaverages', &
            'Could not allocate memory for cformrz')
        if (ldebug) print*, 'allocate_phiaverages : allocated memory for '// &
            'cformrz with nnamerz =', nnamel
      endif
      cformrz=''
!
    endsubroutine allocate_phiaverages
!***********************************************************************
    subroutine fnames_clean_up
!
!  Deallocate space needed for reading the print.in file.
!
!   20-apr-10/Bourdin.KIS: copied from xyaverages_clean_up
!   25-aug-13/MR: added deallocation of itype_name.
!
      if (allocated(fname)) deallocate(fname)
      if (allocated(fname_keep)) deallocate(fname_keep)
      if (allocated(cname)) deallocate(cname)
      if (allocated(cform)) deallocate(cform)
      if (allocated(itype_name)) deallocate(itype_name)
!
    endsubroutine fnames_clean_up
!***********************************************************************
    subroutine vnames_clean_up
!
!  Deallocate space needed for reading the video.in file.
!
!   20-apr-10/Bourdin.KIS: copied from xyaverages_clean_up
!
      if (allocated(cnamev)) deallocate(cnamev)
!
    endsubroutine vnames_clean_up
!***********************************************************************
    subroutine xyaverages_clean_up
!
!  Deallocate the variables needed for xy-averages.
!
!   24-nov-09/anders: copied from yaverages_clean_up
!
      if (allocated(fnamez)) deallocate(fnamez)
      if (allocated(cnamez)) deallocate(cnamez)
      if (allocated(cformz)) deallocate(cformz)
!
    endsubroutine xyaverages_clean_up
!***********************************************************************
    subroutine xzaverages_clean_up
!
!  Deallocate the variables needed for xz-averages.
!
!   24-nov-09/anders: copied from yaverages_clean_up
!
      if (allocated(fnamey)) deallocate(fnamey)
      if (allocated(cnamey)) deallocate(cnamey)
      if (allocated(cformy)) deallocate(cformy)
!
    endsubroutine xzaverages_clean_up
!***********************************************************************
    subroutine yzaverages_clean_up
!
!  Deallocate the variables needed for yz-averages.
!
!   24-nov-09/anders: copied from yaverages_clean_up
!
      if (allocated(fnamex)) deallocate(fnamex)
      if (allocated(cnamex)) deallocate(cnamex)
      if (allocated(cformx)) deallocate(cformx)
!
    endsubroutine yzaverages_clean_up
!***********************************************************************
    subroutine phizaverages_clean_up
!
!  Deallocate the variables needed for phiz-averages.
!
!   24-nov-09/anders: copied from yaverages_clean_up
!
      if (allocated(fnamer)) deallocate(fnamer)
      if (allocated(cnamer)) deallocate(cnamer)
      if (allocated(cformr)) deallocate(cformr)
!
    endsubroutine phizaverages_clean_up
!***********************************************************************
    subroutine yaverages_clean_up
!
!  Deallocate the variables needed for y-averages.
!
!   12-aug-09/dhruba: coded
!
      if (allocated(fnamexz)) deallocate(fnamexz)
      if (allocated(cnamexz)) deallocate(cnamexz)
      if (allocated(cformxz)) deallocate(cformxz)
!
    endsubroutine yaverages_clean_up
!*******************************************************************
    subroutine zaverages_clean_up
!
!  Deallocate the variables needed for z-averages.
!
!   12-aug-09/dhruba: coded
!
      if (allocated(fnamexy)) deallocate(fnamexy)
      if (allocated(cnamexy)) deallocate(cnamexy)
      if (allocated(cformxy)) deallocate(cformxy)
!
    endsubroutine zaverages_clean_up
!*******************************************************************
    subroutine phiaverages_clean_up
!
!  Dellocate the variables needed for phi-averages.
!
!   24-nov-09/anders: copied from zaverages_clean_up
!
      if (allocated(fnamerz)) deallocate(fnamerz)
      if (allocated(cnamerz)) deallocate(cnamerz)
      if (allocated(cformrz)) deallocate(cformrz)
!
    endsubroutine phiaverages_clean_up
!*******************************************************************
    subroutine init_xaver
!
!  Initialize variables for x-averaging.
!
!  26-oct-09/dhruba: coded
!
     integer :: lx
!
     if (xav_max<x(l1)) loutside_avg=.true.
!
     ixav_max=l1
!
     do lx=l1,l2
       if (x(lx)<xav_max) ixav_max=lx
     enddo
!
   endsubroutine init_xaver
!*******************************************************************
   integer function name_is_present(ccname,vlabel,form)
!
!  Verify if the string vlabel is present or not in the ccname array,
!  return index, put format in form if requested and present
!
!  16-sep-10/dintrans: coded
!  16-may-12/MR: changed function type in integer to return index of found name;
!                new optional parameter form for use with print.in
!                where the name vlabel comes with a format specification
!
      character (len=*), dimension(:) :: ccname
      character (len=*)               :: vlabel
      character (len=*), optional     :: form
!
      intent(inout) :: ccname,form
      intent(in) :: vlabel
!
      integer :: mname, i, ind
      logical :: lform
      character (len=intlen) :: str
!
      if (present(form)) then
        lform = form=='T'
        form  = ''
      else
        lform = .false.
      endif
!
      mname = size(ccname)
      name_is_present=0
!
      do i=1,mname
!
        str=ccname(i)
        if (lform) then
          ind = index(str,'(')
          if (ind>1) then
            form=str(ind:)
            str=str(1:ind-1)
          endif
        endif
        if (str == vlabel) then
          name_is_present=i
          return
        endif
      enddo
!
    endfunction name_is_present
!***********************************************************************
endmodule Diagnostics
