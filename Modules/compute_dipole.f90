!
! Copyright (C) 2007-2010 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
! ... original code written by Giovanni Cantele and Paolo Cazzato
! ... adapted to work in the parallel case by Carlo Sbraccia
! ... originally part of the makov_payne.f90 file
! ... adapted to accept any kind of density by Oliviero Andreussi
!
!--------------------------------------------------------------------
SUBROUTINE compute_dipole( nnr, rho, r0, dipole, quadrupole )
!--------------------------------------------------------------------
  USE kinds,            ONLY : DP
  USE cell_base,        ONLY : at, bg, alat, omega
  USE fft_base,         ONLY : dfftp
  USE fft_types,        ONLY : fft_index_to_3d
  USE mp_bands,         ONLY : intra_bgrp_comm
  USE mp,               ONLY : mp_sum
  !
  IMPLICIT NONE
  !
  ! ... Define variables
  !
  !     nnr is passed in input, but nnr should match dfftp%nnr
  !     for the calculation to be meaningful
  INTEGER,  INTENT(IN)  :: nnr
  REAL(DP), INTENT(IN)  :: rho( nnr )
  REAL(DP), INTENT(IN)  :: r0(3)
  REAL(DP), INTENT(OUT) :: dipole(0:3), quadrupole(3)
  !
  ! ... Local variables
  !
  REAL(DP) :: r(3), rhoir
  INTEGER  :: i, j, k, ip, ir, ir_end
  REAL(DP) :: inv_nr1, inv_nr2, inv_nr3
  LOGICAL  :: offrange
  !
  ! ... Initialization
  !
  inv_nr1 = 1.D0 / DBLE( dfftp%nr1 )
  inv_nr2 = 1.D0 / DBLE( dfftp%nr2 )
  inv_nr3 = 1.D0 / DBLE( dfftp%nr3 )
  !
  dipole(:)  = 0.D0
  quadrupole(:) = 0.D0
  !
#if defined (__MPI)
  ir_end = MIN(nnr,dfftp%nr1x*dfftp%my_nr2p*dfftp%my_nr3p)
#else
  ir_end = nnr
#endif
  !
  DO ir = 1, ir_end
     !
     ! ... three dimensional indexes
     !
     CALL fft_index_to_3d (ir, dfftp, i,j,k, offrange)
     IF ( offrange ) CYCLE
     !
     DO ip = 1, 3
        r(ip) = DBLE( i )*inv_nr1*at(ip,1) + &
                DBLE( j )*inv_nr2*at(ip,2) + &
                DBLE( k )*inv_nr3*at(ip,3)
     END DO
     !
     r(:) = r(:) - r0(:)
     !
     ! ... minimum image convention
     !
     CALL cryst_to_cart( 1, r, bg, -1 )
     !
     r(:) = r(:) - ANINT( r(:) )
     !
     CALL cryst_to_cart( 1, r, at, 1 )
     !
     rhoir = rho( ir )
     !
     ! ... dipole(0) = charge density
     !
     dipole(0) = dipole(0) + rhoir
     !
     DO ip = 1, 3
        !
        dipole(ip) = dipole(ip) + rhoir*r(ip)
        quadrupole(ip) = quadrupole(ip) + rhoir*r(ip)**2
        !
     END DO
     !
  END DO
  !
  CALL mp_sum(  dipole(0:3) , intra_bgrp_comm )
  CALL mp_sum(  quadrupole(1:3)  , intra_bgrp_comm )
  !
  dipole(0) = dipole(0)*omega / DBLE( dfftp%nr1*dfftp%nr2*dfftp%nr3 )
  !
  DO ip = 1, 3
     dipole(ip) = dipole(ip)*omega / DBLE( dfftp%nr1*dfftp%nr2*dfftp%nr3 ) * alat
  END DO
  !
  quadrupole = quadrupole*omega / DBLE( dfftp%nr1*dfftp%nr2*dfftp%nr3 ) * alat**2
  !
  RETURN
  !
!----------------------------------------------------------------------------
  END SUBROUTINE compute_dipole
!----------------------------------------------------------------------------
