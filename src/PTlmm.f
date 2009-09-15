c=======================================================================                      
      subroutine ptlmm(datastr,maxni,nrec,nsubject,nfixed,p,q,subject,   
     &                 x,xtx,y,z,                                       
     &                 a0b0,mu0,prec1,prec2,sb,tinv,                    
     &                 mcmc,nsave,                                      
     &                 acrate,cpo,randsave,thetasave,                   
     &                 curr,b,beta,betar,mu,sigma,ortho,mc,             
     &                 iflagp,res,workmp1,workmhp1,workvp1,             
     &                 xty,                                             
     &                 iflagr,parti,whicho,whichn,bz,bzc,limw,linf,lsup,
     &                 propvr,sigmainv,theta,thetac,                    
     &                 workmhr,workmr,workmr1,workmr2,workvr,ybar,      
     &                 sigmac,sigmainvc,workmhr2,                        
     &                 massi,pattern,betasave,bsave)                    
c=======================================================================                      
c     # of arguments = 64.
c
c     Subroutine `ptlmm' to run a Markov chain in a semiparametric 
c     linear mixed effect model using a Mixture of Multivariate Polya 
c     trees prior for the distribution of the random effects.
c
c     Copyright: Alejandro Jara and Timothy Hanson, 2007-2009.
c
c     Version 1.0:
c
c     Last modification: 01-07-2008.
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
c     The authors' contact information:
c
c      Alejandro Jara
c      Department of Statistics
c      Facultad de Ciencias Fisicas y Matematicas
c      Universidad de Concepcion
c      Avenida Esteban Iturra S/N
c      Barrio Universitario
c      Concepcion
c      Chile
c      Voice: +56-41-2203163  URL  : http://www2.udec.cl/~ajarav
c      Fax  : +56-41-2251529  Email: ajarav@udec.cl
c
c      Tim Hanson
c      Division of Biostatistics
c      University of Minnesota
c      School of Public Health
c      A460 Mayo Building, 
c      MMC 303
c      420 Delaware St SE
c      Minneapolis, MN 55455
c      Voice: 612-626-7075  URL  : http://www.biostat.umn.edu/~hanson/
c      Fax  : 612-626-0660  Email: hanson@biostat.umn.edu
c
c---- Data -------------------------------------------------------------
c 
c        datastr     :  integer matrix giving the number of measurements
c                       and the location in y of the observations for 
c                       each subject, datastr(nsubject,maxni+1)
c        maxni       :  integer giving the maximum number of 
c                       measurements for subject.
c        nrec        :  integer giving the number of observations.
c        nsubject    :  integer giving the number of subjects.
c        nfixed      :  integer giving the number of fixed effects,
c                       if nfixed is 0 then p=1.
c        p           :  integer giving the number of fixed coefficients.
c        q           :  integer giving the number of random effects.
c        subject     :  integer vector giving the subject for each.
c                       observation, subject(nsubject).
c        x           :  real matrix giving the design matrix for the 
c                       fixed effects, x(nrec,p). 
c        xtx         :  real matrix givind the product X^tX, xtx(p,p).
c        y           :  real vector giving the response variable,
c                       y(nrec).
c        z           :  real matrix giving the design matrix for the 
c                       random effects, z(nrec,q). 
c
c-----------------------------------------------------------------------
c
c---- Prior information ------------------------------------------------
c 
c        aa0, ab0    :  real giving the hyperparameters of the prior
c                       distribution for the precision parameter,
c                       alpha ~ Gamma(aa0,ab0). If aa0<0 the precision 
c                       parameter is considered as a constant.
c        m           :  integer giving the number of binary partitions
c                       in each margin of the Multivariate
c                       Polya tree prior.
c        mu0         :  real vector giving the prior mean
c                       for the baseline mean, mu0(q).
c        nu0         :  integer giving the degrees of freedom for the
c                       inverted-Wishart prior distribution for the
c                       covariance matrix of the random effects
c                       (This is for the base line).
c        prec1       :  real matrix giving the prior precision matrix
c                       for the fixed effects, prec1(p,p).
c        prec2       :  real matrix giving the prior precision matrix
c                       for the baseline mean, prec2(q,q).
c        sb          :  real vector giving the product of the prior 
c                       precision and prior mean for the fixed effects,
c                       sb(p).
c        tau1, tau2  :  reals giving the hyperparameters of the prior 
c                       distribution for the inverse of the residuals 
c                       variance, 1/sigma2e ~ Gamma(tau1/2,tau2/2).
c        tinv        :  real matrix giving the scale matrix for the
c                       inverted-Wishart prior distribution for the
c                       covariance matrix of the random effects, 
c                       sigma ~ Inv-Wishart(nu0,tinv^{-1}), such that 
c                       E(sigma)=(1/(nu0-q-1)) * tinv 
c                       (This is for the base line distribution).
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
c        samplef     :  integer indicating whether the functionals
c                       must be sampled (1) or not (0).          
c        
c-----------------------------------------------------------------------
c
c---- Output -----------------------------------------------------------
c
c        acrate      :  real vector giving the MH acceptance rate, 
c                       acrate(5). 
c        cpo         :  real giving the cpo. 
c        randsave    :  real matrix containing the mcmc samples for
c                       the random effects and prediction,
c                       randsave(nsave,q*(nsubject+1)).
c        thetasave   :  real matrix containing the mcmc samples for
c                       the averaged random effects, fixed effects, 
c                       error variance, and mean and covariance of
c                       the baseline distribution, 
c                       thetsave(nsave,q+nfixed+1+q+2*nuniq(Sigma)+1+
c                       q*q).
c
c-----------------------------------------------------------------------
c
c---- Current value of the parameters ----------------------------------
c
c        cpar        :  real giving the current value of the precision
c                       parameter of the PT.
c        b           :  real matrix giving the current value of the 
c                       random effects, b(nsubject,q).
c        beta        :  real vector giving the current value of the 
c                       fixed effects, beta(p).
c        betar       :  real vector giving the current value of the 
c                       averaged random effects, betar(q).
c        mu          :  real vector giving the mean of the normal 
c                       base line distribution for the random effects,
c                       mu(q).
c        sigma       :  real matrix giving the current value of the
c                       covariance matrix for normal base line 
c                       distribution for the random effects,
c                       sigma(q,q).
c        sigma2e     :  real giving the current value of the error
c                       variance .
c        ortho       :  real matrix giving the current value of the
c                       orthogonal matrix, ortho(q,q).
c
c-----------------------------------------------------------------------
c
c---- Working space ----------------------------------------------------
c
c        acrate2     :  real working varible
c        bz          :  real matrix giving the current value of the 
c                       standarized random effects, bz(nsubject,q).
c        bzc         :  real matrix giving the candidate value of the 
c                       standarized random effects, bz(nsubject,q).
c        cparc       :  real giving the value of the candidate
c                       for the precision parameter.
c        detlogl     :  real used to save the log-determinant in a
c                       matrix inversion process.
c        detloglc    :  real used to save the log-determinant in a
c                       matrix inversion process.
c        dispcount   :  index. 
c        dlnrm       :  density of a log-normal distribution.
c        dnrm        :  density of a normal distribution.
c        i           :  index. 
c        iflagp      :  integer vector used to invert the of the lhs
c                       least square solution for the fixed effects,
c                       iflagp(p).
c        iflagr      :  integer vector used to invert the of the lhs
c                       least square solution for the random effects,
c                       iflagr(q).
c        ihmssf      :  integer function to evaluate the position of an
c                       element in a matrix based on a half-stored 
c                       version.
c        isave       :  index. 
c        iscan       :  index. 
c        j           :  index. 
c        k           :  index. 
c        l           :  index.
c        limw        :  real vector giving the limits of partitions, 
c                       limw(q).
c        linf        :  real vector giving the limits of partitions, 
c                       linf(q).
c        logcgko     :  real working variable.
c        logcgkn     :  real working variable.
c        loglikec    :  real working variable.
c        loglikeo    :  real working variable.
c        logpriorc   :  real working variable.
c        logprioro   :  real working variable.
c        lsup        :  real vector giving the limits of partitions, 
c                       lsup(q).
c        massi       :  integer vector giving the number of RE
c                       in each element of the partition, massi(2**q).
c        narea       :  integer giving the total number of areas per 
c                       partition, narea=2**q.
c        ni          :  integer indicator used in updating the state. 
c        nscan       :  integer indicating the total number of MCMC
c                       scans.
c        nu          :  real working variable. 
c        parti       :  integer vector giving the partition,
c                       parti(q). 
c        pattern     :  integer vector giving the pattern of an observation,
c                       pattern(q). 
c        propvr      :  real matrix used to update the random effects,
c                       propvr(q,q).
c        ratio       :  real working variable.
c        res         :  real vector used to save the residual effects,
c                       res(nrec).
c        rgamma      :  real gamma random number generator.
c        rtlnorm     :  real truncated log normal random number generator.
c        runif       :  real uniform random number generator.
c        sec         :  cpu time working variable.
c        sec0        :  cpu time working variable.
c        sec00       :  cpu time working variable.
c        sec1        :  cpu time working variable.
c        seed1       :  seed for random number generation.
c        seed2       :  seed for random number generation.
c        sigmac      :  real matrix giving the candidate value of the
c                       baseline covariance matrix, sigmac(q,q).
c        sigmainv    :  real matrix giving the inverse of the current
c                       value of the baseline covariance matrix, 
c                       sigmainv(q,q).
c        sigmainvc   :  real matrix giving the inverse of the candidate
c                       value of the baseline covariance matrix, 
c                       sigmainvc(q,q).
c        skipcount   :  index. 
c        sprint      :  integer function to print on screen.
c        sse         :  real used to save the SS of the errors.
c        theta       :  real vector used to save randomnly generated
c                       random effects, theta(q).
c        thetac      :  real vector used to save randomnly generated
c                       random effects, thetac(q).
c        tmp1        :  real used to accumulate quantities. 
c        tmp2        :  real used to accumulate quantities.
c        whicho      :  integer vector giving the rand. eff. in each
c                       partition, whicho(nsubject).
c        whichn      :  integer vector giving the rand. eff. in each
c                       partition, whichn(nsubject).
c        workmhp1    :  real vector used to update the fixed effects,
c                       workmhp1(p*(p+1)/2)
c        workmhr     :  real vector used to update the random effects,
c                       workmhr(q*(q+1)/2)
c        workmhr2    :  real vector used to update the baseline cov,
c                       workmhr2(q*(q+1)/2)
c        workmp1     :  real matrix used to update the fixed effects,
c                       workmp1(p,p).
c        workmr      :  real matrix used to update the random effects,
c                       workmr(q,q).
c        workmr1     :  real matrix used to update the random effects,
c                       workmr1(q,q).
c        workmr2     :  real matrix used to update the random effects,
c                       workmr2(q,q).
c        workvp1     :  real vector used to update the fixed effects,
c                       workvp1(p)
c        workvr      :  real vector used to update the random effects,
c                       workvr(p)
c        xty         :  real vector used to save the product 
c                       Xt(Y-Zb), xty(p).
c        ybar        :  real vector used to save the mean of random  
c                       effects and the probabilities in each 
c                       partition area, ybar(2**q).
c
c=======================================================================                  
      implicit none 

c+++++Data
      integer maxni,nrec,nsubject,nfixed,p,q,subject(nrec)
      integer datastr(nsubject,maxni+1)
      real*8 y(nrec),x(nrec,p),z(nrec,q),xtx(p,p)
      
c+++++Prior 
      integer fixed,m,murand,sigmarand,typepr
      real*8 aa0,ab0,a0b0(9),mu0(q),nu0,prec1(p,p),prec2(q,q)
      real*8 sb(p)
      real*8 tau1,tau2
      real*8 tinv(q,q)

c+++++MCMC parameters
      integer mcmc(12),nburn,nskip,nsave,ndisplay,nbase,samplef
      real*8 tune1,tune2,tune3,tune4

c+++++Output
      real*8 acrate(5),cpo(nrec,2)
      real*8 randsave(nsave,q*(nsubject+1))
      real*8 thetasave(nsave,q+nfixed+1+q+(q*(q+1))+1+q*q)

c+++++Current values of the parameters
      real*8 cpar,curr(2),beta(p),b(nsubject,q)
      real*8 betar(q)
      real*8 mu(q),sigma2e,sigma(q,q)
      real*8 ortho(q,q)

c++++ model's performance
      real*8 mc(5)
      real*8 betasave(p+1),bsave(nsubject,q)

c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
c+++++External working space
c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

c+++++fixed effects
      integer iflagp(p) 
      real*8 workmp1(p,p)
      real*8 workmhp1(p*(p+1)/2)
      real*8 workvp1(p)
      real*8 xty(p)

c+++++random effects
      integer iflagr(q) 
      integer parti(q)
      integer whicho(nsubject),whichn(nsubject)      
      real*8 bz(nsubject,q),bzc(nsubject,q)
      real*8 limw(q),linf(q),lsup(q)
      real*8 propvr(q,q)
      real*8 sigmainv(q,q)
      real*8 theta(q),thetac(q)
      real*8 workmhr(q*(q+1)/2)
      real*8 workmr(q,q)
      real*8 workmr1(q,q),workmr2(q,q)
      real*8 workvr(q)
      real*8 ybar(2**q)

c+++++errors
      real*8 res(nrec)

c+++++centering covariance matrix
      real*8 sigmac(q,q),sigmainvc(q,q)
      real*8 workmhr2(q*(q+1)/2)

c+++++predictive distribution
      integer massi(2**q)
      integer pattern(q)

c++++ model's performance
      real*8 dbarc,dbar,dhat,pd,lpml

c+++++Working space - RNG
      integer seed1,seed2

c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
c+++++Internal working space
c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

c+++++General
      integer baseskip
      integer dispcount
      integer i,j,k,l
      integer ihmssf
      integer iscan,isave
      integer narea,ni,nscan,nu
      integer skipcount
      integer sprint
      real*8 acrate2,cparc
      real*8 detlogl,detloglc,dlnrm,dnrm
      real*8 logcgkn,logcgko
      real*8 loglikn,logliko
      real*8 logpriorn,logprioro
      real*8 ratio,rnorm,rgamma,rtlnorm,runif,sse,tmp1,tmp2

c+++++CPU time
      real*8 sec00,sec0,sec1,sec

c+++++Adaptive MH for mu
      integer countermh
      real*8 mumh(100),sigmamh(100,100)

c+++++Adaptive MH for sigma
      integer nadaptive
      parameter(nadaptive=2000)
      integer adaptives,sigmaskip
      real*8 aratesigma

c+++++Adaptive MH for c
      integer adaptivec,cskip
      real*8 aratec

c+++++Adaptive MH for partition
      integer adaptivep,pskip
      real*8 aratep

c++++ parameters
      nburn=mcmc(1)
      nskip=mcmc(2)
      ndisplay=mcmc(3)
      nbase=mcmc(4)
      m=mcmc(5)
      seed1=mcmc(6)
      seed2=mcmc(7)
      typepr=mcmc(8)
      murand=mcmc(9)
      sigmarand=mcmc(10)
      fixed=mcmc(11)
      samplef=mcmc(12)

      aa0=a0b0(1)
      ab0=a0b0(2)
      nu0=a0b0(3)
      tau1=a0b0(4)
      tau2=a0b0(5)
      tune1=a0b0(6)
      tune2=a0b0(7)
      tune3=a0b0(8)
      tune4=a0b0(9)
      
      cpar=curr(1)
      sigma2e=curr(2)

      narea=2**q
      
c++++ set random number generator
      call setall(seed1,seed2)

c++++ transforming random effects and calculate log-likelihood
c++++ for the baseline covariance matrix

      call rhaar2(workmr,ortho,q,workmr1)

      logliko=0.d0

      do i=1,q
         mumh(i)=0.d0
         do j=1,q
            sigmamh(i,j)=0.d0
            workmr(i,j)=sigma(i,j)
         end do
      end do
      call inversedet(workmr,q,iflagr,detlogl)

      do i=1,q
         do j=1,q
            workmr(i,j)=0.d0
            sigmainv(i,j)=0.d0
         end do
      end do
      call cholesky(q,sigma,workmhr)
      do i=1,q
         do j=1,i
            workmr(i,j)=workmhr(ihmssf(i,j,q))
         end do
      end do

      do i=1,q
         do j=1,q
            tmp1=0.d0
            do k=1,q
               tmp1=tmp1+workmr(i,k)*workmr1(k,j)
            end do 
            sigmainv(i,j)=tmp1  
         end do
      end do

      call inverse(sigmainv,q,iflagr)      

      call loglikpt_mucan(m,q,nsubject,parti,
     &                    whicho,whichn,b,bz,cpar,detlogl,
     &                    linf,lsup,mu,sigmainv,
     &                    theta,fixed,logliko)

c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
c++++ start the MCMC algorithm
c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      dbar=0.d0
      isave=0
      skipcount=0
      dispcount=0
      baseskip=0
      countermh=0

      adaptives=0
      aratesigma=0.d0
      sigmaskip=0
      if(sigmarand.eq.1.and.tune2.lt.0.d0)then
         adaptives=1
         tune2=10.0
         nburn=nburn+nadaptive
      end if  

      adaptivec=0
      aratec=0.d0
      cskip=0
      if(aa0.gt.0.d0.and.tune3.lt.0.d0)then
         adaptivec=1
         tune3=1.0
         nburn=nburn+nadaptive
      end if  

      adaptivep=0
      aratep=0.d0
      pskip=0
      if(typepr.eq.1.and.tune4.lt.0.d0)then
         adaptivep=1
         tune4=1.d0
         nburn=nburn+nadaptive
      end if  

      nscan=nburn+(nskip+1)*(nsave)

      call cpu_time(sec0)
      sec00=0.d0
      
      do iscan=1,nscan

c+++++++ check if the user has requested an interrupt
         call rchkusr()

c++++++++++++++++++++++++++++++++
c+++++++ fixed effects        +++
c++++++++++++++++++++++++++++++++

         if(nfixed.eq.0)go to 1
            do i=1,p
               xty(i)=sb(i)
            end do

            do i=1,nrec
               tmp1=0.d0
               do j=1,q
                  tmp1=tmp1+z(i,j)*b(subject(i),j) 
               end do
               tmp1=y(i)-tmp1
             
               do j=1,p
                  xty(j)=xty(j)+x(i,j)*(tmp1/sigma2e)
               end do
            end do

            do i=1,p
               do j=1,p
                  workmp1(i,j)=xtx(i,j)/sigma2e+prec1(i,j)          
               end do
            end do

            call inverse(workmp1,p,iflagp)      

            do i=1,p
               tmp1=0.d0
               do j=1,p
                  tmp1=tmp1+workmp1(i,j)*xty(j) 
               end do
               workvp1(i)=tmp1
            end do

            call rmvnorm(p,workvp1,workmp1,workmhp1,xty,beta)
1        continue            


         if(nfixed.eq.0)then
             do i=1,nrec
                res(i)=y(i) 
             end do
           else
             do i=1,nrec
                tmp1=0.d0
                do j=1,p
                   tmp1=tmp1+x(i,j)*beta(j)    
                end do
                res(i)=y(i)-tmp1
             end do
         end if  
         
c+++++++++++++++++++++++++++++++++
c+++++++ random effects        +++ 
c+++++++++++++++++++++++++++++++++

         acrate2=0.d0

         do i=1,q
            ybar(i)=0.d0
            do j=1,q
               workmr(i,j)=sigma(i,j)
            end do
            workvr(i)=0.d0
            iflagr(i)=0
         end do

         call inverse(workmr,q,iflagr)      

         do i=1,nsubject

c++++++++++ check if the user has requested an interrupt
            call rchkusr()

            do j=1,q
               theta(j)=b(i,j)
            end do   

c++++++++++ generating a candidate
            do j=1,q
               do k=1,q
                  propvr(j,k)=workmr(j,k)
               end do
               workvr(j)=0.d0
               iflagr(j)=0
            end do

            ni=datastr(i,1) 
            logliko=0.d0

            do j=1,q
               do k=1,q
                  tmp1=0.d0
                  do l=1,ni
                     tmp1=tmp1+z(datastr(i,l+1),j)*
     &                         z(datastr(i,l+1),k)/sigma2e
                  end do
                  propvr(j,k)=propvr(j,k)+tmp1
               end do
            end do

            call inverse(propvr,q,iflagr)      

            call rmvnorm(q,theta,propvr,workmhr,workvr,thetac)

c++++++++++ evaluating the likelihood
            loglikn=0.d0
            logliko=0.d0

            do j=1,ni

               tmp1=0.d0
               do k=1,p
                  tmp1=tmp1+x(datastr(i,j+1),k)*beta(k)   
               end do
               
               do k=1,q
                  tmp1=tmp1+z(datastr(i,j+1),k)*theta(k)   
               end do
               
               logliko=logliko+dnrm(y(datastr(i,j+1)),
     &                              tmp1,sqrt(sigma2e),1)

               tmp1=0.d0
               do k=1,p
                  tmp1=tmp1+x(datastr(i,j+1),k)*beta(k)   
               end do

               do k=1,q
                  tmp1=tmp1+z(datastr(i,j+1),k)*thetac(k)   
               end do
               
               loglikn=loglikn+dnrm(y(datastr(i,j+1)),
     &                              tmp1,sqrt(sigma2e),1)

            end do

c++++++++++ evaluating the prior

            logprioro=0.d0
            logpriorn=0.d0

            do j=1,q
               limw(j)=bz(i,j)
            end do

            call condptprior(limw,i,nsubject,q,bz,cpar,m,detlogl,
     &                       linf,lsup,parti,whicho,whichn,
     &                       fixed,logprioro)

            do j=1,q
               tmp1=0.d0
               do k=1,q
                  tmp1=tmp1+sigmainv(j,k)*(thetac(k)-mu(k))   
               end do
               limw(j)=tmp1
            end do

            call condptprior(limw,i,nsubject,q,bz,cpar,m,detlogl,
     &                       linf,lsup,parti,whicho,whichn,
     &                       fixed,logpriorn)

c++++++++++ mh step
  
            ratio=loglikn-logliko+
c     &            logcgkn-logcgko+
     &            logpriorn-logprioro

            if(log(dble(runif())).lt.ratio)then
               acrate2=acrate2+1.d0
               do j=1,q
                  b(i,j)=thetac(j)
                  bz(i,j)=limw(j)
               end do
            end if

         end do

         acrate(1)=acrate(1)+acrate2/dble(nsubject)


c++++++++++++++++++++++++++++++++++         
c+++++++ error variance         +++
c++++++++++++++++++++++++++++++++++

c+++++++ check if the user has requested an interrupt
         call rchkusr()

         sse=0.d0 

         do i=1,nrec
            tmp1=0.d0
            do j=1,q
               tmp1=tmp1+z(i,j)*b(subject(i),j) 
            end do
            res(i)=res(i)-tmp1
            sse=sse+res(i)*res(i)
         end do

         sigma2e=1.d0/
     &           rgamma(0.5d0*(dble(nrec)+tau1),0.5d0*(sse+tau2))
     


         baseskip = baseskip + 1
         if(baseskip.ge.nbase)then
         countermh=countermh+1

c++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
c+++++++ Updating mu using a MH step                        +++
c++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

c+++++++ update the log-likelihood for random effects

         if(murand.eq.1.or.sigmarand.eq.1.or.aa0.gt.0.d0.or.
     &      typepr.eq.1)then            
            call loglikpt_updatet(m,q,nsubject,parti,
     &                         whicho,whichn,bz,cpar,detlogl,
     &                         linf,lsup,
     &                         fixed,logliko)
         end if

         if(murand.eq.1)then

c++++++++++ generating a candidate

            if(tune1.gt.0.d0)then 

               do i=1,q
                  do j=1,q
                     propvr(i,j)=(tune1)*sigma(i,j)/dble(nsubject)
                  end do
               end do
               call rmvnorm(q,mu,propvr,workmhr,workvr,theta)

             else  
               if(countermh.le.nburn/2)then
                  do i=1,q
                     do j=1,q
                        propvr(i,j)=(0.01d0)*sigma(i,j)/dble(nsubject)
                     end do
                  end do
                  call rmvnorm(q,mu,propvr,workmhr,workvr,theta)
                else
                  ratio=dble(runif())
                  if(ratio.le.0.25)then
                     do i=1,q
                        do j=1,q
                           propvr(i,j)=(5.4264d0/dble(q))*sigmamh(i,j)
                        end do
                     end do
                     call rmvnorm(q,mu,propvr,workmhr,workvr,theta)
                   else if(ratio.le.0.5)then
                     do i=1,q
                        do j=1,q
                          propvr(i,j)=sigma(i,j)/dble(nsubject)
                        end do
                     end do
                     call rmvnorm(q,mu,propvr,workmhr,workvr,theta)
                   else
                     do i=1,q
                        do j=1,q
                          propvr(i,j)=0.01d0*sigma(i,j)/dble(nsubject)
                        end do
                     end do
                     call rmvnorm(q,mu,propvr,workmhr,workvr,theta)
                  end if  
               end if  
            end if

c++++++++++ evaluating priors 

            logpriorn=0.d0
            logprioro=0.d0
         
            do i=1,q
               do j=1,q
                  logpriorn=logpriorn+(theta(i)-mu0(i))* 
     &                                 prec2(i,j)    *
     &                                 (theta(j)-mu0(j))

                  logprioro=logprioro+(mu(i)-mu0(i))* 
     &                                 prec2(i,j)    *
     &                                (mu(j)-mu0(j))

               end do
            end do
         
            logpriorn=-0.5d0*logpriorn
            logprioro=-0.5d0*logprioro

c++++++++++ evaluating likelihood for muc

            call loglikpt_mucan(m,q,nsubject,parti,
     &                         whicho,whichn,b,bzc,cpar,detlogl,
     &                         linf,lsup,theta,sigmainv,
     &                         thetac,fixed,loglikn)


c++++++++++ acceptance step

            ratio=loglikn-logliko+logpriorn-logprioro

            if(log(dble(runif())).lt.ratio)then
               do i=1,q
                  mu(i)=theta(i)
               end do
               do i=1,nsubject
                  do j=1,q
                     bz(i,j)=bzc(i,j)
                  end do   
               end do
               logliko=loglikn
               acrate(2)=acrate(2)+1.d0
            end if
            
c++++++++++ addapting the parameters for the MH algorithm
            if(countermh.eq.1)then
               do i=1,q
                  mumh(i)=mu(i)
                  do j=1,q
                     sigmamh(i,j)=sigma(i,j)/dble(nsubject)
                  end do
               end do
             else
               do i=1,q
                  do j=1,q
                     sigmamh(i,j)=sigmamh(i,j)+(1.d0/dble(countermh))*
     &               ( 
     &                (mu(i)-mumh(i))*(mu(j)-mumh(j)) - 
     &                (dble(countermh)/dble(countermh-1))*sigmamh(i,j)
     &               ) 
                  end do
               end do
            
               do i=1,q
                  mumh(i)=mumh(i)+(1.d0/dble(countermh))*(mu(i)-mumh(i))
               end do
            end if
            
         end if

c++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
c+++++++ Updating sigma using a MH step                     +++
c++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

         if(sigmarand.eq.1)then


c++++++++++ Addaptive MH

            if(adaptives.eq.1)then  
               sigmaskip = sigmaskip + 1
               if(sigmaskip.eq.100)then
                  aratesigma=aratesigma/dble(100)

                  if(iscan.le.nadaptive)then  
                     if(q.eq.1)then
                        if(aratesigma.lt.0.44)then
                           tune2=exp(log(tune2)+(0.44-aratesigma))
                         else
                           tune2=exp(log(tune2)-(aratesigma-0.44))
                        end if  
                       else
                        if(aratesigma.lt.0.234)then
                           tune2=exp(log(tune2)+(0.234-aratesigma))
                         else
                           tune2=exp(log(tune2)-(aratesigma-0.234))
                        end if  
                     end if  

                   else 
                     if(q.eq.1)then
                        if(aratesigma.lt.0.44)then
                           tune2=exp(log(tune2)+
     &                      min(0.01,1.d0/sqrt(dble(iscan-nadaptive))))
                          else
                           tune2=exp(log(tune2)-
     &                      min(0.01,1.d0/sqrt(dble(iscan-nadaptive))))
                        end if  
                       else
                        if(aratesigma.lt.0.234)then
                           tune2=exp(log(tune2)+
     &                      min(0.01,1.d0/sqrt(dble(iscan-nadaptive))))
                          else
                           tune2=exp(log(tune2)-
     &                      min(0.01,1.d0/sqrt(dble(iscan-nadaptive))))
                        end if  
                     end if  
                  end if
                  
                  nu=(dble(nsubject))*tune2
                  if(nu.le.(q+1))tune2=dble(q+2)/dble(nsubject)
                  
                  sigmaskip=0
                  aratesigma=0.d0
               end if
            end if

c++++++++++ START: Simple MH
c++++++++++ generating the candidate value

            nu=(dble(nsubject))*tune2
         
            do i=1,q
               do j=1,q
                  sigmac(i,j)=dble(nu-q-1)*sigma(i,j)
               end do
            end do

            call riwishart(q,nu,sigmac,workmr2,workmr,workvr,
     &                     workmhr,workmhr2,iflagr)

c++++++++++ evaluating the candidate generating kernel

            do i=1,q
               do j=1,q
                  propvr(i,j)=dble(nu-q-1)*sigma(i,j)
               end do
            end do

            call diwishart(q,nu,sigmac,propvr,workmr1,workmr2,workvr,
     &                     iflagr,logcgko)        

            do i=1,q
               do j=1,q
                  propvr(i,j)=dble(nu-q-1)*sigmac(i,j)
               end do
            end do

            call diwishart(q,nu,sigma,propvr,workmr1,workmr2,workvr,
     &                     iflagr,logcgkn)        

c++++++++++ ENDS: Simple MH

c++++++++++ evaluating the prior

            call diwishart(q,int(nu0),sigmac,tinv,workmr1,workmr2,
     &                     workvr,iflagr,logpriorn)        

            call diwishart(q,int(nu0),sigma,tinv,workmr1,workmr2,
     &                     workvr,iflagr,logprioro)        

c++++++++++ evaluating likelihood for sigmac

            call rhaar2(workmr,ortho,q,workmr1)

            call loglikpt_covarcan2(m,q,nsubject,iflagr,parti,
     &                              whicho,whichn,b,bzc,cpar,detloglc,
     &                              linf,lsup,mu,sigmac,sigmainvc,
     &                              workmr1,workvr,workmhr,workmr,
     &                              loglikn,fixed)


c++++++++++ acceptance step
         
            ratio=loglikn-logliko+logcgkn-logcgko+
     &            logpriorn-logprioro

            if(log(dble(runif())).lt.ratio)then
               do i=1,q
                  do j=1,q
                     sigma(i,j)=sigmac(i,j)
                     sigmainv(i,j)=sigmainvc(i,j)
                  end do
               end do
               do i=1,nsubject
                  do j=1,q
                     bz(i,j)=bzc(i,j)
                  end do   
               end do 
               detlogl=detloglc
               logliko=loglikn
               acrate(3)=acrate(3)+1.d0

               if(adaptives.eq.1)aratesigma=aratesigma+1.d0

            end if
         end if

c++++++++++++++++++++++++++++++++++++++++++++++++++++++++
c+++++++ MH to update the c parameter                 +++
c++++++++++++++++++++++++++++++++++++++++++++++++++++++++

         if(aa0.gt.0.d0)then

c++++++++++ Addaptive MH

            if(adaptivec.eq.1)then  
               cskip = cskip + 1
               if(cskip.eq.100)then
                  aratec=aratec/dble(100)
                  if(iscan.le.nadaptive)then  
                     if(aratec.lt.0.44)then
                        tune3=exp(log(tune3)+(0.44-aratec))
                      else
                        tune3=exp(log(tune3)-(aratec-0.44))
                     end if  
                   else 
                     if(aratec.gt.0.44)then
                        tune3=exp(log(tune3)+
     &                        min(0.01,1.d0/sqrt(dble(iscan))))
                       else
                        tune3=exp(log(tune3)-
     &                        min(0.01,1.d0/sqrt(dble(iscan))))
                     end if 
                  end if    
                  cskip=0
                  aratec=0.d0
               end if
            end if


c++++++++++ sample candidates

            cparc=rtlnorm(log(cpar),tune3*1.0,0,0,.true.,.true.)
            logcgkn=dlnrm(cpar ,log(cparc),tune3*1.0,1) 
            logcgko=dlnrm(cparc,log(cpar ),tune3*1.0,1) 

c++++++++++ evaluate log-prior for candidate value of the parameters

            call dgamma2(cparc,aa0,ab0,logpriorn)  

c++++++++++ evaluate log-prior for current value of parameters

            call dgamma2(cpar ,aa0,ab0,logprioro)


c++++++++++ evaluate log-likelihood for candidate value of 
c++++++++++ the parameters

            call loglikpt_cparcan(m,q,nsubject,iflagr,parti,
     &                            whicho,whichn,bz,cparc,detlogl,
     &                            linf,lsup,
     &                            theta,fixed,loglikn)

c++++++++++ acceptance step
            ratio=loglikn+logpriorn-logliko-logprioro+
     &            logcgkn-logcgko

            if(log(dble(runif())).lt.ratio)then
               cpar=cparc
               acrate(4)=acrate(4)+1.d0
               logliko=loglikn

               if(adaptivec.eq.1)aratec=aratec+1.d0
               
            end if            
         end if
         baseskip=0

         end if

c++++++++++++++++++++++++++++++++++++++++++++++++++++++++
c+++++++ Updating the partition                       +++
c++++++++++++++++++++++++++++++++++++++++++++++++++++++++

         if(typepr.eq.1)then

c++++++++++ Addaptive MH

            if(adaptivep.eq.1)then  
               pskip = pskip + 1
               if(pskip.eq.100)then
                  aratep=aratep/dble(100)
                  if(iscan.le.nadaptive)then  
                     if(aratep.lt.0.234)then
                        tune4=exp(log(tune4)+(0.234-aratep))
                      else
                        tune4=exp(log(tune4)-(aratep-0.234))
                     end if  
                   else 
                     if(aratep.gt.0.234)then
                        tune4=exp(log(tune4)+
     &                        min(0.01,1.d0/sqrt(dble(iscan))))
                       else
                        tune4=exp(log(tune4)-
     &                        min(0.01,1.d0/sqrt(dble(iscan))))
                     end if 
                  end if    
                  pskip=0
                  aratep=0.d0
               end if
            end if

c            call rhaar(q,workmr1,propvr)

            do i=1,q
               do j=1,q   
                   workmr2(i,j)=rnorm(ortho(i,j),tune4*0.05d0)
               end do
            end do
            call rhaar2(workmr,workmr2,q,propvr)

            call loglikpt_covarcan2(m,q,nsubject,iflagr,parti,
     &                              whicho,whichn,b,bzc,cpar,detloglc,
     &                              linf,lsup,mu,sigma,sigmainvc,
     &                              propvr,workvr,workmhr,workmr,
     &                              loglikn,fixed)

c++++++++++ acceptance step
         
            ratio=loglikn-logliko

            if(log(dble(runif())).lt.ratio)then
               acrate(5)=acrate(5)+1.d0
               do i=1,q
                  do j=1,q
                     ortho(i,j)=workmr2(i,j)
                     sigmainv(i,j)=sigmainvc(i,j)
                  end do
               end do

               do i=1,nsubject
                  do j=1,q
                     bz(i,j)=bzc(i,j)
                  end do   
               end do 
               detlogl=detloglc
               logliko=loglikn

               if(adaptivep.eq.1)aratep=aratep+1.d0

            end if
         end if 

c++++++++++++++++++++++++++++++++++         
c+++++++ save samples
c++++++++++++++++++++++++++++++++++         

         curr(1)=cpar
         curr(2)=sigma2e
         
         if(iscan.gt.nburn)then
            skipcount=skipcount+1
            if(skipcount.gt.nskip)then
               isave=isave+1
               dispcount=dispcount+1

c+++++++++++++ random effects

               k=0
               do i=1,nsubject
                  do j=1,q
                     bsave(i,j)=bsave(i,j)+b(i,j)
                     k=k+1
                     randsave(isave,k)=b(i,j)
                  end do   
               end do


c+++++++++++++ predictive information

               call sampredptun(narea,q,nsubject,parti,m,ybar,
     &               massi,pattern,iflagr,whichn,whicho,bz,
     &               cpar,limw,linf,lsup,thetac,fixed)

               do i=1,q
                  do j=1,q
                     propvr(i,j)=0.d0
                     workmr(i,j)=0.d0
                  end do
               end do
               call cholesky(q,sigma,workmhr)
               do i=1,q
                  do j=1,i
                     propvr(i,j)=workmhr(ihmssf(i,j,q))
                  end do
               end do

               call rhaar2(workmr,ortho,q,workmr1)

               do i=1,q
                  do j=1,q
                     tmp1=0.d0
                     do k=1,q
                        tmp1=tmp1+propvr(i,k)*workmr1(k,j) 
                     end do 
                     workmr(i,j)=tmp1
                  end do
               end do

               k=nsubject*q
               do i=1,q
                  tmp1=0.d0
                  do j=1,q
                     tmp1=tmp1+workmr(i,j)*thetac(j)   
                  end do
                  theta(i)=tmp1+mu(i)
                  k=k+1
                  randsave(isave,k)=theta(i)
               end do

c+++++++++++++ functional parameter

               if(samplef.eq.1)then

               call samplefuncpt(fixed,m,q,nsubject,cpar,bz,theta,
     &                           iflagr,pattern,thetac,workmr1)  

               do i=1,q
                  tmp1=0.d0
                  do j=1,q
                     tmp1=tmp1+workmr(i,j)*thetac(j)   
                  end do
                  betar(i)=tmp1+mu(i)
               end do

               do i=1,q
                  do j=1,q
                     tmp1=0.d0  
                     do k=1,q
                        tmp1=tmp1+workmr(i,k)*workmr1(k,j)
                     end do
                     propvr(i,j)=tmp1
                  end do
               end do

               do i=1,q
                  do j=1,q
                     tmp1=0.d0  
                     do k=1,q
                        tmp1=tmp1+propvr(i,k)*workmr(j,k)
                     end do
                     workmr1(i,j)=tmp1
                  end do
               end do
               
c+++++++++++++ regression coefficients

               do i=1,q
                  thetasave(isave,i)=betar(i)
               end do

               end if

               if(nfixed.gt.0)then
                  do i=1,p
                     thetasave(isave,q+i)=beta(i)
                     betasave(i)=betasave(i)+beta(i)
                  end do
               end if   

c+++++++++++++ error variance

               thetasave(isave,q+nfixed+1)=sigma2e
               betasave(p+1)=betasave(p+1)+sigma2e

c+++++++++++++ baseline mean

               do i=1,q
                  thetasave(isave,q+nfixed+1+i)=mu(i)
               end do

c+++++++++++++ baseline covariance

               k=0
               do i=1,q
                  do j=i,q
                     k=k+1
                     thetasave(isave,q+nfixed+1+q+k)=sigma(i,j)
                  end do
               end do

c+++++++++++++ precision parameter
               k=(q*(q+1)/2)  
               thetasave(isave,q+nfixed+1+q+k+1)=cpar

c+++++++++++++ orthogonal matrix
               call rhaar2(workmr,ortho,q,workmr2)

               k=(q*(q+1)/2)+1
               do i=1,q
                  do j=1,q
                     k=k+1
                     thetasave(isave,q+nfixed+1+q+k)=workmr2(i,j) 
                  end do
               end do   

c+++++++++++++ random effects variance
               if(samplef.eq.1)then
               k=(q*(q+1)/2)+1+q*q
               l=0
               do i=1,q
                  do j=i,q
                     l=l+1
                     thetasave(isave,q+nfixed+1+q+k+l)=workmr1(i,j)
                  end do
               end do
               end if   

c+++++++++++++ cpo
               dbarc=0.d0
               do i=1,nrec
                  tmp1=0.d0
                  if(nfixed.gt.0)then
                     do j=1,p
                        tmp1=tmp1+x(i,j)*beta(j)
                     end do   
                  end if
                  do j=1,q
                     tmp1=tmp1+z(i,j)*b(subject(i),j) 
                  end do
                  tmp2=dnrm(y(i),tmp1,sqrt(sigma2e),0)
                  cpo(i,1)=cpo(i,1)+1.0d0/tmp2  
                  cpo(i,2)=cpo(i,2)+tmp2  
                  tmp2=dnrm(y(i),tmp1,sqrt(sigma2e),1)
                  dbarc=dbarc+tmp2
               end do

c+++++++++++++ dic
               dbar=dbar-2.d0*dbarc

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

      do i=1,1
         acrate(i)=acrate(i)/dble(nscan)
      end do
      do i=2,4
         acrate(i)=acrate(i)*dble(nbase)/dble(nscan)
      end do
      acrate(5)=acrate(5)/dble(nscan)
      
      do i=1,nrec
         cpo(i,1)=dble(nsave)/cpo(i,1)
         cpo(i,2)=cpo(i,2)/dble(nsave)
      end do

      do i=1,p+1
         betasave(i)=betasave(i)/dble(nsave)
      end do

      do i=1,nsubject
         do j=1,q
            bsave(i,j)=bsave(i,j)/dble(nsave)
         end do
      end do   

      dhat=0.d0
      lpml=0.d0
      do i=1,nrec
         tmp1=0.d0
         if(nfixed.gt.0)then
            do j=1,p
               tmp1=tmp1+x(i,j)*betasave(j)
            end do   
         end if
         do j=1,q
            tmp1=tmp1+z(i,j)*bsave(subject(i),j) 
         end do
         dhat=dhat+dnrm(y(i),tmp1,sqrt(betasave(p+1)),1)
         lpml=lpml+log(cpo(i,1))
      end do
      dhat=-2.d0*dhat

      dbar=dbar/dble(nsave)
      pd=dbar-dhat
      
      mc(1)=dbar
      mc(2)=dhat
      mc(3)=pd
      mc(4)=dbar+pd
      mc(5)=lpml
      
      return
      end
         