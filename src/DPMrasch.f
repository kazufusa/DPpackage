
c=======================================================================                      
      subroutine dpmrasch(datastrm,imiss,nmissing,nsubject,p,y,roffset,
     &                    ngrid,grid,
     &                    maxn,a0b0,m0,s0,prec,sb,tau,
     &                    mcmc,nsave,
     &                    acrate,cpo,cpov,
     &                    randsave,thetasave,densave,cdfsave,
     &                    alpha,b,beta,ss,ncluster,mub,sigmab,tauk2,
     &                    wdp,vdp,muclus,sigmaclus,
     &                    betac,workvp,workmhp,xtx,xty,iflagp,
     &                    cstrt,ccluster,prob,workv,
     &                    seed)
c=======================================================================                      
c
c     Copyright: Alejandro Jara, 2007-2010.
c
c     Version 1.0:
c
c     Last modification: 25-09-2009.
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
c      Alejandro Jara
c      Department of Statistics
c      Facultad de Matematicas
c      Pontificia Universidad Catolica de Chile
c      Casilla 306, Correo 22 
c      Santiago
c      Chile
c      Voice: +56-2-3544506  URL  : http://www.mat.puc.cl/~ajara
c      Fax  : +56-2-3547729  Email: atjara@uc.cl
c
c=======================================================================

      implicit none 

c+++++Data
      integer imiss,nmissing,nsubject,p
      integer datastrm(nmissing,2),y(nsubject,p)
      real*8 roffset(nsubject,p)

c+++++Density estimation
      integer ngrid
      real*8 grid(ngrid)

c+++++Prior 
      integer maxn
      real*8 aa0,ab0,a0b0(2),sb(p-1,2),prec(p-1,p-1)
      real*8 m0,s0
      real*8 tau(5),tauk1,taub1,taub2,taus1,taus2

c+++++MCMC parameters
      integer mcmc(3),nburn,nskip,nsave,ndisplay

c+++++Output
      real*8 acrate(2)
      real*8 cpo(nsubject,p)
      real*8 cpov(nsubject)
      real*8 randsave(nsave,nsubject)
      real*8 thetasave(nsave,p+6)
      real*8 densave(nsave,ngrid)
      real*8 cdfsave(nsave,ngrid)

c+++++Current values of the parameters
      integer ncluster,ss(nsubject)     
      real*8 alpha,beta(p-1),b(nsubject)
      real*8 muclus(maxn),sigmaclus(maxn)
      real*8 mub,sigmab
      real*8 tauk2
      real*8 wdp(maxn),vdp(maxn)

c+++++Working space - General
      integer i,ii,j,k
      integer sprint
      integer ns,ok
      real*8 ztz,zty
      real*8 dbin,dnrm,cdfnorm
      real*8 tmp1,tmp2,tmp3
      real*8 muwork,sigmawork
      real*8 mureal,sigma2real

c+++++Working space - RNG
      integer evali,seed(2),seed1,seed2
      real*8 rnorm,rgamma
      real runif

c+++++Working space - MCMC
      integer iscan,isave,nscan
      integer skipcount,dispcount

c+++++Working space - Difficulty parameters
      integer iflagp(p-1)
      real*8 betac(p-1)
      real*8 xtx(p-1,p-1)
      real*8 xty(p-1)
      real*8 workmhp((p-1)*p/2)
      real*8 workvp(p-1)

c+++++DPM
      integer cstrt(maxn,nsubject)
      integer ccluster(maxn)
      real*8 prob(maxn)
      real*8 workv(maxn+1)

c+++++Working space - GLM part
      integer yij
      real*8 acrate2
      real*8 eta,offset,gprime,ytilde,mean
       
c+++++Working space - MH 
      real*8 bc,logcgkn,logcgko,logliko,loglikn,ratio
      real*8 logpriorn,logprioro 

c+++++CPU time
      real*8 sec00,sec0,sec1,sec

c++++ parameters
      nburn=mcmc(1)
      nskip=mcmc(2)
      ndisplay=mcmc(3)
      aa0=a0b0(1)
      ab0=a0b0(2)
      
      tauk1=tau(1)
      taub1=tau(2)
      taub2=tau(3)
      taus1=tau(4)
      taus2=tau(5)

c++++ set random number generator
      seed1=seed(1)
      seed2=seed(2)
      
      call setall(seed1,seed2)
     
c++++ set configurations
      do i=1,nsubject
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

c+++++++ check if the user has requested an interrupt
         call rchkusr()

c++++++++++++++++++++++++++++++++++
c+++++++ missing data
c++++++++++++++++++++++++++++++++++

         if(imiss.eq.1)then

c++++++++++ check if the user has requested an interrupt
            call rchkusr()

            do ii=1,nmissing
               i=datastrm(ii,1)
               j=datastrm(ii,2)
               if(j.eq.1)then
                 eta=b(i)+roffset(i,j)
                else
                 eta=b(i)-beta(j-1)+roffset(i,j)
               end if
               
               mean=exp(eta)/(1.d0+exp(eta))
               
               call rbinom(1,mean,evali)
               y(i,j)=evali
            end do
         end if

c++++++++++++++++++++++++++++++++++
c+++++++ difficulty parameters
c++++++++++++++++++++++++++++++++++

c+++++++ generating the candidate

         do i=1,p-1
            do j=1,p-1
               xtx(i,j)=prec(i,j)
            end do
            xty(i)=sb(i,1)
         end do

         logliko=0.d0         
         
         do i=1,nsubject

c++++++++++ check if the user has requested an interrupt
            call rchkusr()

            do j=1,p-1
               yij=y(i,j+1)            
               eta=b(i)-beta(j)+roffset(i,j+1) 
               offset=b(i)+roffset(i,j+1) 
               mean=exp(eta)/(1.d0+exp(eta))
               logliko=logliko+dbin(dble(yij),1.d0,mean,1)

               tmp1=mean*(1.0d0-mean)
               gprime=1.d0/tmp1

               ytilde=eta+(dble(yij)-mean)*gprime-offset
               xtx(j,j)=xtx(j,j)+1.d0/gprime
               xty(j)=xty(j)-ytilde/gprime

            end do
         end do

         call inverse(xtx,p-1,iflagp)      
         do i=1,p-1
            tmp1=0.d0
            do j=1,p-1
               tmp1=tmp1+xtx(i,j)*xty(j) 
            end do
            workvp(i)=tmp1
         end do

         call rmvnorm(p-1,workvp,xtx,workmhp,xty,betac)

c+++++++ evaluating the candidate generating kernel

         call dmvnd(p-1,betac,workvp,xtx,logcgko,iflagp)
  
c+++++++ prior ratio

         logprioro=0.d0
         logpriorn=0.d0
         
         do i=1,p-1
            do j=1,p-1
               logpriorn=logpriorn+(betac(i)-sb(i,2))* 
     &                    prec(i,j)      *
     &                   (betac(j)-sb(j,2))

               logprioro=logprioro+(beta(i) -sb(i,2))* 
     &                    prec(i,j)      *
     &                   (beta(j) -sb(j,2))
            end do
         end do
         
         logpriorn=-0.5d0*logpriorn
         logprioro=-0.5d0*logprioro
            
c+++++++ candidate generating kernel contribution

         do i=1,p-1
            do j=1,p-1
               xtx(i,j)=prec(i,j)
            end do
            xty(i)=sb(i,1)
         end do

         loglikn=0.d0         
         
         do i=1,nsubject

c++++++++++ check if the user has requested an interrupt
            call rchkusr()

            do j=1,p-1
               yij=y(i,j+1)            
               eta=b(i)-betac(j)+roffset(i,j+1) 
               offset=b(i)+roffset(i,j+1)
               mean=exp(eta)/(1.d0+exp(eta))
               loglikn=loglikn+dbin(dble(yij),1.d0,mean,1)

               tmp1=mean*(1.0d0-mean)
               gprime=1.d0/tmp1

               ytilde=eta+(dble(yij)-mean)*gprime-offset
               xtx(j,j)=xtx(j,j)+1.d0/gprime
               xty(j)=xty(j)-ytilde/gprime
            end do
         end do

         call inverse(xtx,p-1,iflagp)      
         do i=1,p-1
            tmp1=0.d0
            do j=1,p-1
               tmp1=tmp1+xtx(i,j)*xty(j) 
            end do
            workvp(i)=tmp1
         end do

c+++++++ evaluating the candidate generating kernel
            
         call dmvnd(p-1,beta,workvp,xtx,logcgkn,iflagp)

c+++++++ mh step
           
         ratio=loglikn-logliko+logcgkn-logcgko+
     &         logpriorn-logprioro

         if(log(runif()).lt.ratio)then
            acrate(1)=acrate(1)+1.d0
            do i=1,p-1
               beta(i)=betac(i) 
            end do
         end if

c         call dblepr("loglikn",-1,loglikn,1)
c         call dblepr("logliko",-1,logliko,1)
c         call dblepr("logcgkn",-1,logcgkn,1)
c         call dblepr("logcgko",-1,logcgko,1)
c         call dblepr("logpriorn",-1,logpriorn,1)
c         call dblepr("logprioro",-1,logprioro,1)
c         call dblepr("lratio",-1,ratio,1)
c         call dblepr("beta",-1,beta,p-1)

c++++++++++++++++++++++++++++++++++         
c+++++++ random effects 
c++++++++++++++++++++++++++++++++++

         acrate2=0.d0

         do i=1,nsubject

c++++++++++ check if the user has requested an interrupt
            call rchkusr()

c++++++++++ generates the candidate

            logliko=0.d0         

            ztz=1.d0/sigmaclus(ss(i))
            zty=muclus(ss(i))/sigmaclus(ss(i))

            do j=1,p
               yij=y(i,j) 
               if(j.eq.1)then
                  eta=b(i)+roffset(i,j) 
                  offset=roffset(i,j)
                 else          
                  eta=b(i)-beta(j-1)+roffset(i,j)
                  offset=-beta(j-1)+roffset(i,j)
               end if  
               mean=exp(eta)/(1.d0+exp(eta))
               logliko=logliko+dbin(dble(yij),1.d0,mean,1)

               tmp1=mean*(1.0d0-mean)
               gprime=1.d0/tmp1

               ytilde=eta+(dble(yij)-mean)*gprime-offset
               ztz=ztz+1.d0/gprime
               zty=zty+ytilde/gprime
            end do

            ztz=1.d0/ztz
            zty=ztz*zty

            bc=rnorm(zty,sqrt(ztz))

c++++++++++ evaluating the candidate generating kernel

            logcgko=dnrm(bc,zty,sqrt(ztz),1)

c++++++++++ prior ratio

            muwork=muclus(ss(i))
            sigmawork=sigmaclus(ss(i))
 
            logprioro=dnrm(b(i),muwork,sqrt(sigmawork),1)
            logpriorn=dnrm(bc  ,muwork,sqrt(sigmawork),1)

c++++++++++ candidate generating kernel contribution

            loglikn=0.d0         

            ztz=1.d0/sigmaclus(ss(i))
            zty=muclus(ss(i))/sigmaclus(ss(i))

            do j=1,p
               yij=y(i,j) 
               if(j.eq.1)then
                  eta=bc+roffset(i,j) 
                  offset=roffset(i,j)
                 else          
                  eta=bc-beta(j-1)+roffset(i,j)
                  offset=-beta(j-1)+roffset(i,j)
               end if  
               mean=exp(eta)/(1.d0+exp(eta))
               loglikn=loglikn+dbin(dble(yij),1.d0,mean,1)

               tmp1=mean*(1.0d0-mean)
               gprime=1.d0/tmp1

               ytilde=eta+(dble(yij)-mean)*gprime-offset
               ztz=ztz+1.d0/gprime
               zty=zty+ytilde/gprime
            end do

            ztz=1.d0/ztz
            zty=ztz*zty

c++++++++++ evaluating the candidate generating kernel

            logcgkn=dnrm(b(i),zty,sqrt(ztz),1)


c++++++++++ mh step
           
            ratio=loglikn-logliko+logcgkn-logcgko+
     &            logpriorn-logprioro

            if(log(runif()).lt.ratio)then
               acrate2=acrate2+1.d0
               b(i)=bc
            end if
         end do

         acrate(2)=acrate(2)+acrate2/dble(nsubject)

c         call dblepr("b",-1,b,nsubject)

c+++++++++++++++++++++++++++++++++++++         
c+++++++ clustering structure 
c+++++++++++++++++++++++++++++++++++++

         do i=1,nsubject

c++++++++++ check if the user has requested an interrupt
            call rchkusr()

            ns=ccluster(ss(i))
            
            if(ns.gt.1)then
               ccluster(ss(i))=ccluster(ss(i))-1 
               j=1
               ok=0
               do while(ok.eq.0.and.j.le.ns)
                  if(cstrt(ss(i),j).eq.i)ok=j
                  j=j+1
               end do

               do j=ok,ns-1
                  cstrt(ss(i),j)=cstrt(ss(i),j+1)
               end do

             else
               ccluster(ss(i))=ccluster(ss(i))-1 
               ncluster=ncluster-1
            end if 
         
            do j=1,maxn
               muwork=muclus(j)                
               sigmawork=sigmaclus(j)
               tmp2=dnrm(b(i),muwork,sqrt(sigmawork),0)
               prob(j)=wdp(j)*tmp2
            end do
            call simdisc(prob,maxn,maxn,evali)

            ss(i)=evali
            ccluster(evali)=ccluster(evali)+1
            cstrt(evali,ccluster(evali))=i
            if(ccluster(evali).eq.1)ncluster=ncluster+1
         end do

c         call intpr("ss",-1,ss,nsubject)

c+++++++++++++++++++++++++++++++++++++         
c+++++++ DP weights 
c+++++++++++++++++++++++++++++++++++++
         call dpweightsimbl(maxn,ccluster,alpha,workv,wdp,vdp)

c         call dblepr("wdp",-1,wdp,maxn)
     

c+++++++++++++++++++++++++++++++++++
c+++++++ kernel means            +++
c+++++++++++++++++++++++++++++++++++

         do i=1,maxn

            ztz=1.d0/sigmab
            zty=mub/sigmab

            ns=ccluster(i)
            if(ns.gt.0)then 
               ztz=ztz+dble(ns)/sigmaclus(i)
               do j=1,ns
c++++++++++++++++ check if the user has requested an interrupt
                  call rchkusr()

                  ii=cstrt(i,j)
                  zty=zty+b(ii)/sigmaclus(i)
               end do
            end if  
 
            tmp1=zty/ztz
            tmp2=1.d0/ztz

            muclus(i)=rnorm(tmp1,sqrt(tmp2))

         end do

c         call dblepr("mu",-1,muclus,maxn)

c+++++++++++++++++++++++++++++++++++
c+++++++ kernel variances        +++
c+++++++++++++++++++++++++++++++++++

         do i=1,maxn

c++++++++++ check if the user has requested an interrupt
            call rchkusr()

            ns=ccluster(i)
            tmp2=0.0
           
            if(ns.gt.0)then
               do j=1,ns

c++++++++++++++++ check if the user has requested an interrupt
                  call rchkusr()

                  ii=cstrt(i,j)
                  tmp1=b(ii)-muclus(i)
                  tmp2=tmp2+tmp1*tmp1
               end do
            end if

            sigmaclus(i)=1.d0/rgamma(0.5d0*(tauk1+dble(ns)),
     &                   0.5d0*(tauk2+tmp2))
         end do

c         call dblepr("sigma",-1,sigmaclus,maxn)

c+++++++++++++++++++++++++++++++++++
c+++++++ precision parameter     +++
c+++++++++++++++++++++++++++++++++++

         if(a0b0(1).gt.0.0)then

            call samalph(alpha,a0b0(1),a0b0(2),ncluster,nsubject)

c            tmp1=0.d0
c            do i=1,maxn-1
c               tmp1=tmp1+log(1.d0-vdp(i)) 
c            end do
c            alpha=rgamma(dble(maxn)+a0b0(1)-1.d0,a0b0(2)-tmp1)

c            call dblepr("alpha",-1,alpha,1)
         end if 


c++++++++++++++++++++++++++++++++++++++         
c+++++++ baseline mean
c++++++++++++++++++++++++++++++++++++++

         if(s0.gt.0.d0)then
            ztz=1.d0/s0
            zty=m0/s0

            do i=1,maxn
c+++++++++++++ check if the user has requested an interrupt
               call rchkusr()
               ztz=ztz+1.d0
               zty=zty+muclus(i)/sigmab
            end do

            tmp1=zty/ztz
            tmp2=1.d0/ztz

            mub=rnorm(tmp1,sqrt(tmp2))
         end if


c++++++++++++++++++++++++++++++++++++++         
c+++++++ baseline variance
c++++++++++++++++++++++++++++++++++++++

         if(taub1.gt.0.d0)then

            tmp1=0.d0
            do i=1,maxn
               tmp2=muclus(i)-mub
               tmp1=tmp1+tmp2*tmp2
            end do
 
            sigmab=1.d0/
     &           rgamma(0.5d0*(dble(maxn)+taub1),0.5d0*(tmp1+taub2))
         end if


c++++++++++++++++++++++++++++++++++++++
c+++++++ baseline gamma parameter   +++
c++++++++++++++++++++++++++++++++++++++

         if(taus1.gt.0.d0)then

            tmp1=0.d0
            do i=1,maxn
               tmp1=tmp1+1.d0/sigmaclus(i)
            end do 

            tauk2=rgamma(0.5d0*(dble(maxn)*tauk1+taus1),
     &                   0.5d0*(tmp1+taus2))   

         end if

c++++++++++++++++++++++++++++++++++         
c+++++++ save samples
c++++++++++++++++++++++++++++++++++         
         
         if(iscan.gt.nburn)then
            skipcount=skipcount+1
            if(skipcount.gt.nskip)then
               isave=isave+1
               dispcount=dispcount+1

c+++++++++++++ difficulty parameters

               do i=1,p-1
                  thetasave(isave,i)=beta(i)
               end do

c+++++++++++++ computing mean and variance

               mureal=0.d0
               sigma2real=0.d0

               do ii=1,maxn
                  sigmawork=sigmaclus(ii)
                  muwork=muclus(ii)
                  mureal=mureal+wdp(ii)*muwork
                  sigma2real=sigma2real+wdp(ii)*
     &                (muwork*muwork+sigmawork)
               end do
               sigma2real=sigma2real-mureal*mureal

c+++++++++++++ real mean and variance
               thetasave(isave,p)=mureal
               thetasave(isave,p+1)=sigma2real

c+++++++++++++ precision parameter
               thetasave(isave,p+2)=ncluster
               thetasave(isave,p+3)=alpha

c+++++++++++++ baseline parameters
               thetasave(isave,p+4)=mub
               thetasave(isave,p+5)=sigmab
               thetasave(isave,p+6)=tauk2

c+++++++++++++ random effects
               do i=1,nsubject
                  randsave(isave,i)=b(i)
               end do

c+++++++++++++ density and cdf

               do i=1,ngrid
                  ytilde=grid(i)
                  tmp1=0.d0
                  tmp2=0.d0
                  do j=1,maxn
                     muwork=muclus(j)
                     sigmawork=sigmaclus(j)
                     tmp1=tmp1+wdp(j)*dnrm(ytilde,muwork,
     &                                     sqrt(sigmawork),0) 
                     tmp2=tmp2+wdp(j)*cdfnorm(ytilde,muwork,
     &                                        sqrt(sigmawork),1,0) 
                  end do
                  densave(isave,i)=tmp1
                  cdfsave(isave,i)=tmp2
               end do

c+++++++++++++ cpo

               do i=1,nsubject
                  tmp2=0.d0
                  do j=1,p
                     yij=y(i,j)
                     if(j.eq.1)then
                       eta=b(i)+roffset(i,j)
                      else
                       eta=b(i)-beta(j-1)+roffset(i,j)
                     end if  
                     mean=exp(eta)/(1.d0+exp(eta))
                     tmp1=dbin(dble(yij),1.d0,mean,1)
                     cpo(i,j)=cpo(i,j)+1.0d0/exp(tmp1)
                     tmp2=tmp2+tmp1
                  end do
                  cpov(i)=cpov(i)+1.d0/exp(tmp2)
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
      
      do i=1,2
         acrate(i)=acrate(i)/dble(nscan)    
      end do   
      
      do i=1,nsubject
         do j=1,p
            cpo(i,j)=dble(nsave)/cpo(i,j)
         end do   
         cpov(i)=dble(nsave)/cpov(i)  
      end do

      return
      end


