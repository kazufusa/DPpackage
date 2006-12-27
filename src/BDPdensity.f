    
c=======================================================================                      
      subroutine bdpdensity(nrec,jacob,x,                               #3
     &                      a0b0,a0,b0,kmax,                            #4
     &                      k,ncluster,ss,alpha,yclus,                  #5
     &                      mcmc,nsave,                                 #2
     &                      cpo,randsave,thetasave,ngrid,grid,fun,      #6 
     &                      seed,                                       #1
     &                      cstrt,ccluster,prob,probk,y)                #5 
c=======================================================================                      
c     # of arguments = 26.
c
c     Subroutine `bdpdensity' to run a Markov chain for a 
c     Bernstein-Dirichlet model.
c
c     Copyright: Alejandro Jara, 2007
c
c     Version 1.0:
c
c     Last modification: 20-05-2007.
c
c     This program is free software; you can redistribute it and/or modify
c     it under the terms of the GNU General Public License as published by
c     the Free Software Foundation; either version 2 of the License, or (at
c     your option) any later version.
c
c     This program is distributed in the hope that it will be useful, but
c     WITHOUT ANY WARRANTY; without even the implied warranty of
c     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
c     General Public License for more details.
c
c     You should have received a copy of the GNU General Public License
c     along with this program; if not, write to the Free Software
c     Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
c
c     The author's contact information:
c
c     Alejandro Jara
c     Biostatistical Centre
c     Katholieke Universiteit Leuven
c     U.Z. Sint-Rafa�l
c     Kapucijnenvoer 35
c     B-3000 Leuven
c     Voice: +32 (0)16 336892 
c     Fax  : +32 (0)16 337015 
c     URL  : http://student.kuleuven.be/~s0166452/
c     Email: Alejandro.JaraVallejos@med.kuleuven.be
c
c---- Data -------------------------------------------------------------
c 
c        nrec        :  integer giving the number of data points. 
c        jacob       :  real giving the jacobian of the trasnformation.
c        x           :  real vector giving the transformed data, x(nrec). 
c
c-----------------------------------------------------------------------
c
c---- Prior information ------------------------------------------------
c 
c        aa0, ab0    :  real giving the hyperparameters of the prior
c                       distribution for the precision parameter,
c                       alpha ~ Gamma(aa0,ab0). If aa0<0 the precision 
c                       parameter is considered as a constant.
c        a0,b0       :  real giving the parameters of the Beta centering
c                       distribution.
c        kmax        :  integer giving the upper limit of the discrete
c                       uniform prior for the degree of the Bernstein 
c                       polynomial. 
c
c-----------------------------------------------------------------------
c
c---- MCMC parameters --------------------------------------------------
c
c        nburn       :  integer giving the number of burn-in scans.
c        ndisplay    :  integer giving the number of saved scans to be
c                       displayed on screen.
c        nskip       :  integer giving the thinning interval.
c        nsave       :  integer giving the number of scans to be saved.
c        nbase       :  integer giving the the number of scans where 
c                       the baseline distribution and the precision
c                       parameter are sampled.
c        
c-----------------------------------------------------------------------
c
c---- Output -----------------------------------------------------------
c
c        cpo         :  real giving the cpo. 
c        randsave    :  real matrix containing the mcmc samples for
c                       the latent variables and prediction,
c                       randsave(nsave,nrec+1).
c        thetasave   :  real matrix containing the mcmc samples for
c                       k, the number of clusters and alpha, 
c                       thetsave(nsave,3).
c        ngrid       :  integer giving the length of the grid.
c        grid        :  real vector giving the grid where the density 
c                       is evaluated, grid(ngrid).
c        fun         :  real vector giving the density estimate, on 
c                       the original scale of the data, fun(ngrid).
c
c-----------------------------------------------------------------------
c
c---- Current value of the parameters ----------------------------------
c
c        k           :  integer giving the current value of the 
c                       degree of the polynomial.
c        ncluster    :  integer giving the number of clusters.
c        ss          :  integer vector giving the configurations.
c        alpha       :  real giving the current value of the precision
c                       parameter of the DP.
c        yculs       :  real vector giving the value of the latent 
c                       variables, yclus(nrec).
c
c-----------------------------------------------------------------------
c
c---- Working space ----------------------------------------------------
c
c        ccluster    :  integer vector indicating the number of
c                       subjects in each cluster, ccluster(nrec).
c        cstrt       :  integer matrix used to save the cluster
c                       structure, cstrt(nrec,nrec).
c        prob        :  real vector used to update the cluster 
c                       structure, prob(nrec+1).
c        prob        :  real vector used to update the degree of BP,
c                       probk(kmax).
c        dispcount   :  index. 
c        i           :  index. 
c        isave       :  index. 
c        iscan       :  index. 
c        j           :  index. 
c        k           :  index. 
c        l           :  index.
c        nscan       :  integer indicating the total number of MCMC
c                       scans.
c        sec         :  cpu time working variable.
c        sec0        :  cpu time working variable.
c        sec00       :  cpu time working variable.
c        sec1        :  cpu time working variable.
c        seed1       :  seed for random number generation.
c        seed2       :  seed for random number generation.
c        skipcount   :  index. 
c        sprint      :  integer function to print on screen.
c        tmp1        :  real used to accumulate quantities. 
c        tmp2        :  real used to accumulate quantities.
c        tmp3        :  real used to accumulate quantities.
c        y           :  real vector giving the current value of the 
c                       latent variables, y(nrec).
c
c=======================================================================                  
     
      implicit none 

c+++++Data
      integer nrec
      real*8 jacob
      real*8 x(nrec)

c+++++Prior 
      integer kmax
      real*8 aa0,ab0,a0b0(2),a0,b0

c+++++Current values of the parameters
      integer k,ncluster,ss(nrec)
      real*8 alpha
      real*8 yclus(nrec)

c+++++MCMC parameters
      integer mcmc(3),nburn,nskip,nsave,ndisplay

c+++++Output
      integer ngrid
      real*8 cpo(nrec,2)
      real*8 randsave(nsave,nrec+1)
      real*8 thetasave(nsave,3)
      real*8 grid(ngrid),fun(ngrid)

c+++++Seeds
      integer seed(2),seed1,seed2

c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
c+++++External working space
c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

c+++++DP
      integer cstrt(nrec,nrec)
      integer ccluster(nrec)
      real*8 prob(nrec+1)
      
c+++++K
      real*8 probk(kmax)
      real*8 y(nrec)

c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
c+++++Internal working space
c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

c+++++General
      integer evali,i,j,l,ns,ok
      integer since,sprint 
      real*8 tmp1,tmp2,tmp3

c+++++MCMC
      integer dispcount,isave,iscan,nscan,skipcount 

c+++++CPU time
      real*8 sec00,sec0,sec1,sec

c+++++RNG and distributions
      real*8 rbeta,dbet

c++++ parameters
      nburn=mcmc(1)
      nskip=mcmc(2)
      ndisplay=mcmc(3)
      
      aa0=a0b0(1)
      ab0=a0b0(2)

c++++ set random number generator
      seed1=seed(1)
      seed2=seed(2)
      call setall(seed1,seed2)

c++++ set configurations
      do i=1,nrec
         ccluster(ss(i))=ccluster(ss(i))+1
         cstrt(ss(i),ccluster(ss(i)))=i
      end do
      
    
c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
c++++ start the MCMC algorithm
c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      isave=0
      skipcount=0
      dispcount=0
      nscan=nburn+(nskip+1)*(nsave)

      call cpu_time(sec0)
      sec00=0.d0
      
      do iscan=1,nscan
      

c+++++++++++++++++++++++++++++++++++++++++++++++++
c+++++++ a) Polya Urn
c+++++++++++++++++++++++++++++++++++++++++++++++++

c+++++++ check if the user has requested an interrupt
         call rchkusr()
         
         do i=1,nrec

            ns=ccluster(ss(i))

c++++++++++ subject in cluster with more than 1 observations
             
            if(ns.gt.1)then
               j=1
               ok=0
               do while(ok.eq.0.and.j.le.ns)
                  if(cstrt(ss(i),j).eq.i)ok=j
                  j=j+1
               end do
   
               do j=ok,ns-1
                  cstrt(ss(i),j)=cstrt(ss(i),j+1)
               end do
          
               ccluster(ss(i))=ccluster(ss(i))-1 
               
               do j=1,ncluster
                  call clustevalbd(x(i),k,yclus(j),tmp1)
                  prob(j)=dble(ccluster(j))*tmp1
               end do
               call baseevalbd(x(i),k,a0,b0,tmp1)               
               prob(ncluster+1)=alpha*tmp1
               call simdisc(prob,nrec+1,ncluster+1,evali)               

               ss(i)=evali
               ccluster(evali)=ccluster(evali)+1
               cstrt(evali,ccluster(evali))=i

               if(evali.gt.ncluster)then
                  ncluster=ncluster+1
                  call sampleybd(x(i),kmax,a0,b0,k,tmp1)                  
                  yclus(evali)=tmp1
               end if
            end if

c++++++++++ subject in cluster with only 1 observation
             
            if(ns.eq.1)then
                
               since=ss(i)
                
               if(since.lt.ncluster)then
                   call  relabelmeta(i,since,nrec,ncluster,cstrt,
     &                               ccluster,ss,yclus)
	       end if
	              
               ccluster(ncluster)=ccluster(ncluster)-1 
               ncluster=ncluster-1

               do j=1,ncluster
                  call clustevalbd(x(i),k,yclus(j),tmp1)
                  prob(j)=dble(ccluster(j))*tmp1
               end do
               call baseevalbd(x(i),k,a0,b0,tmp1)               
               prob(ncluster+1)=alpha*tmp1
               call simdisc(prob,nrec+1,ncluster+1,evali)               

               ss(i)=evali
               ccluster(evali)=ccluster(evali)+1
               cstrt(evali,ccluster(evali))=i
               
               if(evali.gt.ncluster)then
                  ncluster=ncluster+1
                  call sampleybd(x(i),kmax,a0,b0,k,tmp1)                  
                  yclus(evali)=tmp1
               end if            
            end if  
         end do
         
c+++++++++++++++++++++++++++++++++++++++++++++++++
c+++++++ b) Resampling
c+++++++++++++++++++++++++++++++++++++++++++++++++

c+++++++ check if the user has requested an interrupt
         call rchkusr()
         
         do i=1,ncluster
            do j=1,ccluster(i)
               y(cstrt(i,j))=yclus(i)
            end do
         end do   

c+++++++++++++++++++++++++++++++++++++++++++++++++
c+++++++ Sampling k
c+++++++++++++++++++++++++++++++++++++++++++++++++

c+++++++ check if the user has requested an interrupt
         call rchkusr()

         call samplekbd(nrec,x,y,probk,kmax,k)

c++++++++++++++++++++++++++++++++++         
c+++++++ Precision parameter
c++++++++++++++++++++++++++++++++++

c+++++++ check if the user has requested an interrupt
         call rchkusr()

         if(aa0.gt.0.d0)then
            call samalph(alpha,aa0,ab0,ncluster,nrec)
         end if 

c++++++++++++++++++++++++++++++++++         
c+++++++ save samples
c++++++++++++++++++++++++++++++++++         
         
         if(iscan.gt.nburn)then
            skipcount=skipcount+1
            if(skipcount.gt.nskip)then
               isave=isave+1
               dispcount=dispcount+1

c+++++++++++++ k,ncluster,alpha
               thetasave(isave,1)=k
               thetasave(isave,2)=ncluster
               thetasave(isave,3)=alpha
               
c+++++++++++++ y
               do i=1,nrec
                  randsave(isave,i)=y(i)
               end do

c+++++++++++++ predictive information

               do i=1,ncluster
                  prob(i)=dble(ccluster(i))/(alpha+dble(nrec))
               end do
               prob(ncluster+1)=alpha/(alpha+dble(nrec))

               call simdisc(prob,nrec+1,ncluster+1,evali)
               
               if(evali.le.ncluster)then
                  tmp1=yclus(evali)
               end if
               if(evali.gt.ncluster)then
                  tmp1=rbeta(a0,b0)
               end if
               randsave(isave,nrec+1)=tmp1

               do i=1,ngrid
                  tmp1=0.d0
                  do j=1,ncluster
                     call jcomponentbd(yclus(j),k,l)                  
                     tmp2=dbet(grid(i),dble(l),dble(k-l+1),0)   
                     tmp1=tmp1+tmp2*prob(j)
                  end do
                  tmp3=rbeta(a0,b0)
                  call jcomponentbd(tmp3,k,l)                  
                  tmp2=dbet(grid(i),dble(l),dble(k-l+1),0)   
                  tmp1=tmp1+tmp2*prob(ncluster+1) 
                  fun(i)=fun(i)+tmp1                    
               end do

c+++++++++++++ cpo

               do i=1,nrec
                  call jcomponentbd(y(i),k,l)                   
                  tmp1=dbet(x(i),dble(l),dble(k-l+1),0)*jacob
                  cpo(i,1)=cpo(i,1)+1.0d0/tmp1  
                  cpo(i,2)=cpo(i,2)+tmp1  
               end do

c+++++++++++++ print
               skipcount = 0
               if(dispcount.ge.ndisplay)then
                  call cpu_time(sec1)
                  sec00=sec00+(sec1-sec0)
                  sec=sec00
                  sec0=sec1
                  tmp1=sprint(isave,nsave,sec)
                  dispcount=0
               end if   
            end if
         end if
      end do

      do i=1,nrec
         cpo(i,1)=dble(nsave)/cpo(i,1)
         cpo(i,2)=cpo(i,2)/dble(nsave)                                             
      end do

      do i=1,ngrid
         fun(i)=fun(i)/dble(nsave)       
      end do     

      do i=1,ngrid
         fun(i)=fun(i)*jacob
      end do     

      return
      end