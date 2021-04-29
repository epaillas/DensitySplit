program tophat_filter
  use OMP_LIB
  use procedures
  implicit none
  
  real*8 :: rgrid_x, rgrid_y, rgrid_z, vol, mean_density
  real*8 :: boxsize, box2
  real*8 :: disx, disy, disz, dis, dis2
  real*8 :: dim1_min2, dim1_max2
  real*8 :: dim1_max, dim1_min, rfilter, rgrid
  real*8 :: pi = 4.*atan(1.)
  
  integer*8 :: ndata2, ndata1
  integer*8 :: i, ii, ix, iy, iz, ix2, iy2, iz2
  integer*8 :: ipx, ipy, ipz, ndif
  integer*8 :: ngrid
  
  integer*8, dimension(:, :, :), allocatable :: lirst
  integer*8, dimension(:), allocatable :: ll
  
  real*8, allocatable, dimension(:,:)  :: data2, data1
  real*8, dimension(:), allocatable :: D1D2, delta, weight1, weight2

  logical :: has_velocity1 = .false., has_velocity2 = .false.
  
  character(20), external :: str
  character(len=500) :: data_filename2, data_filename1, output_filename
  character(len=10) :: dim1_max_char, dim1_min_char
  character(len=10) :: boxchar, rfilter_char
  character(len=10) :: ngridchar
  
  if (iargc() .lt. 8) then
      write(*,*) 'Some arguments are missing.'
      write(*,*) '1) input_data'
      write(*,*) '2) data_filename1'
      write(*,*) '3) output_filename'
      write(*,*) '4) boxsize'
      write(*,*) '5) dim1_min'
      write(*,*) '6) dim1_max'
      write(*,*) '7) rfilter'
      write(*,*) '8) ngrid'
      write(*,*) ''
      stop
    end if
    
  call get_command_argument(number=1, value=data_filename2)
  call get_command_argument(number=2, value=data_filename1)
  call get_command_argument(number=3, value=output_filename)
  call get_command_argument(number=4, value=boxchar)
  call get_command_argument(number=5, value=dim1_min_char)
  call get_command_argument(number=6, value=dim1_max_char)
  call get_command_argument(number=7, value=rfilter_char)
  call get_command_argument(number=8, value=ngridchar)
  
  read(boxchar, *) boxsize
  read(dim1_min_char, *) dim1_min
  read(dim1_max_char, *) dim1_max
  read(rfilter_char, *) rfilter
  read(ngridchar, *) ngrid

  write(*,*) '-----------------------'
  write(*,*) 'Running tophat_filter.exe'
  write(*,*) 'input parameters:'
  write(*,*) ''
  write(*, *) 'data_filename2: ', trim(data_filename2)
  write(*, *) 'data_filename1: ', trim(data_filename1)
  write(*, *) 'boxsize: ', trim(boxchar)
  write(*, *) 'output_filename: ', trim(output_filename)
  write(*, *) 'dim1_min: ', trim(dim1_min_char), ' Mpc'
  write(*, *) 'dim1_max: ', trim(dim1_max_char), ' Mpc'
  write(*, *) 'rfilter: ', trim(rfilter_char), 'Mpc'
  write(*, *) 'ngrid: ', trim(ngridchar)
  write(*,*) ''

  call read_unformatted(data_filename1, data1, weight1, ndata1, has_velocity1)
  call read_unformatted(data_filename2, data2, weight2, ndata2, has_velocity2)
  call linked_list(data2, boxsize, ngrid, ll, lirst, rgrid)

  allocate(D1D2(ndata1))
  allocate(delta(ndata1))
  
  mean_density = ndata2 / (boxsize ** 3)
  D1D2 = 0
  delta = 0
  ndif = int(dim1_max / rgrid + 1.)
  dim1_min2 = dim1_min * dim1_min
  dim1_max2 = dim1_max * dim1_max
  box2 = boxsize / 2
  
  !$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(i, ii, ipx, ipy, &
  !$OMP ipz, ix, iy, iz, ix2, iy2, iz2, disx, disy, disz, dis2)
  do i = 1, ndata1
    ipx = int(data1(1, i) / rgrid_x + 1.)
    ipy = int(data1(2, i) / rgrid_y + 1.)
    ipz = int(data1(3, i) / rgrid_z + 1.)
  
    do ix = ipx - ndif, ipx + ndif
      do iy = ipy - ndif, ipy + ndif
        do iz = ipz - ndif, ipz + ndif
  
          ix2 = ix
          iy2 = iy
          iz2 = iz
  
          if (ix2 .gt. ngrid) ix2 = ix2 - ngrid
          if (ix2 .lt. 1) ix2 = ix2 + ngrid
          if (iy2 .gt. ngrid) iy2 = iy2 - ngrid
          if (iy2 .lt. 1) iy2 = iy2 + ngrid
          if (iz2 .gt. ngrid) iz2 = iz2 - ngrid
          if (iz2 .lt. 1) iz2 = iz2 + ngrid
  
          ii = lirst(ix2,iy2,iz2)
          if(ii .ne. 0) then
            do
              ii = ll(ii)
              disx = data2(1, ii) - data1(1, i)
              disy = data2(2, ii) - data1(2, i)
              disz = data2(3, ii) - data1(3, i)

              if (disx .lt. -box2) disx = disx + boxsize
              if (disx .gt. box2) disx = disx - boxsize
              if (disy .lt. -box2) disy = disy + boxsize
              if (disy .gt. box2) disy = disy - boxsize
              if (disz .lt. -box2) disz = disz + boxsize
              if (disz .gt. box2) disz = disz - boxsize
  
              dis2 = disx * disx + disy * disy + disz * disz

              if (dis2 .gt. dim1_min2 .and. dis .lt. dim1_max2) then
                D1D2(i) = D1D2(i) + weight1(i) * weight2(ii)
              end if

              if(ii .eq. lirst(ix2,iy2,iz2)) exit
  
            end do
          end if
        end do
      end do
    end do

  vol = 4./3 * pi * (dim1_max ** 3 - dim1_min ** 3)
  delta(i) = D1D2(i) / (vol * mean_density) - 1

  end do
  !$OMP END PARALLEL DO
  
  write(*,*) ''
  write(*,*) 'Calculation finished. Writing output...'
  
  open(12, file=output_filename, status='replace', form='unformatted')
  write(12) ndata1
  write(12) delta

end program tophat_filter
    