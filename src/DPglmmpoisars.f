
c=======================================================================                      
      subroutine dpglmmpoisars(
     &                     datastr,maxni,mpar,nrec,nsubject,nfixed,p,q, #8
     &                     subject,x,y,z,roffset,                       #5 
     &                     a0b0,b0,nu0,prec,psiinv,sb,smu,tinv,         #8
     &                     mcmc,nsave,                                  #2
     &                     acrate,cpo,randsave,thetasave,               #4
     &                     alpha,b,bclus,beta,betar,mu,ncluster,sigma,  #8
     &                     sigmainv,ss,mc,                              #3
     &                     betac,ccluster,iflagp,iflagb,newtheta,prob,  #6 
     &                     quadf,seed,theta,thetac,workp1,workp2,workb1,#7
     &                     workb2,workmh1,workmh2,workmh3,workvp1,      #5 
     &                     workvb1,workvb2,xtx,xty,                     #4
     &                     zty,ztz,cstrt,betasave,bsave)                #5
c=======================================================================                      
c     # of arguments = 65.
c
c     Subroutine `dpglmmpoisars' to run a Markov chain in the  
c     semiparametric poison mixed model. In this routine, inference 
c     is based on  the Polya urn representation of Dirichlet process.
c     The algorithm 8 with m=1 of Neal (2000) is used to sample the 
c     configurations. The ARS derivative-dependent is used to move the
c     cluster's location.
c
c     Copyright: Alejandro Jara, 2006-2007
c 
c     Version 2.0: 
c
c     Last modification: 25-04-2007.
c
c     Changes and Bug fixes: 
c
c     Version 1.0 to Version 2.0:
c          - The "population" parameters betar are computed as a 
c            functional of a DP instead of base on simple averages of
c            the random effects.
c          - The computation of the DIC was added.
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
c        roffset     :  real vector giving the real offset for each
c                       observation.
c        subject     :  integer vector giving the subject for each.
c                       observation, subject(nsubject).
c        x           :  real matrix giving the design matrix for the 
c                       fixed effects, x(nrec,p). 
c        y           :  integer matrix giving the response variable,
c                       y(nrec).
c        z           :  real matrix giving the design matrix for the 
c                       random effects, z(nrec,q). 
c-----------------------------------------------------------------------
c
c---- Prior information ------------------------------------------------
c 
c        aa0, ab0    :  real giving the hyperparameters of the prior
c                       distribution for the precision parameter,
c                       alpha ~ Gamma(aa0,ab0). If aa0<0 the precision 
c                       parameter is considered as a constant.
c        b0          :  real vector giving the prior mean of fixed
c                       effects, b0(p).
c        nu0         :  integer giving the degrees of freedom for the
c                       inverted-Wishart prior distribution for the
c                       covariance matrix of the random effects
c                       (This is for the base line).
c        prec        :  real matrix giving the prior precision matrix
c                       for the fixed effects, prec(p,p).
c        psiinv      :  real matrix giving the prior precision matrix
c                       for the baseline mean, psiinv(q,q).
c        sb          :  real vector giving the product of the prior 
c                       precision and prior mean for the fixed effects,
c                       sb(p).
c        smu         :  real vector giving the product of the prior 
c                       precision and prior mean for the baseline mean,
c                       smu(q).
c        tinv        :  real matrix giving the scale matrix for the
c                       inverted-Wishart prior distribution for the
c                       covariance matrix of the random effects, 
c                       sigma ~ Inv-Wishart(nu0,tinv^{-1}), such that 
c                       E(sigma)=(1/(nu0-q-1)) * tinv 
c                       (This is for the base line distribution)
c-----------------------------------------------------------------------
c
c---- MCMC parameters --------------------------------------------------
c
c        nburn       :  integer giving the number of burn-in scans.
c        ndisplay    :  integer giving the number of saved scans to be
c                       displayed on screen.
c        nskip       :  integer giving the thinning interval.
c        nsave       :  integer giving the number of scans to be saved.
c        
c-----------------------------------------------------------------------
c
c---- Output -----------------------------------------------------------
c
c        acrate      :  real vector giving the MH acceptance rate. 
c        cpo         :  real giving the cpo, acrate(2).
c        randsave    :  real matrix containing the mcmc samples for
c                       the random effects and prediction,
c                       randsave(nsave,q*(nsubject+1))
c                       thetsave(nsave,q+nfixed+1+q+nuniq(Sigma)+2).
c        thetasave   :  real matrix containing the mcmc samples for
c                       the averaged random effects, fixed effects, 
c                       error variance, and mean and covariance of
c                       the baseline distribution, 
c                       thetsave(nsave,q+nfixed+q+nuniq(Sigma)+2).
c
c-----------------------------------------------------------------------
c
c---- Current value of the parameters ----------------------------------
c
c        alpha       :  real giving the current value of the precision
c                       parameter of the Dirichlet process.
c        b           :  real matrix giving the current value of the 
c                       random effects, b(nsubject,q).
c        bclus       :  real matrix giving the current value of the 
c                       different values of random effects, 
c                       bclus(nsubject,q).
c        beta        :  real vector giving the current value of the 
c                       fixed effects, beta(p).
c        betar       :  real vector giving the current value of the 
c                       averaged random effects, betar(q).
c        mu          :  real vector giving the mean of the normal 
c                       base line distribution for the random effects,
c                       mu(q).
c        ncluster    :  integer giving the number of clusters in the
c                       random effects.
c        sigma       :  real matrix giving the current value of the
c                       covariance matrix for normal base line 
c                       distribution for the random effects,
c                       sigma(q,q).
c        sigmainv    :  real matrix used to save the base line 
c                       covariance matrix for the random effects,
c                       sigmainv(q,q).
c        ss          :  integer vector giving the cluster label for 
c                       each subject, ss(nsubject).
c-----------------------------------------------------------------------
c
c---- Working space ----------------------------------------------------
c
c        acrate2     :  real used to calculate the acceptance rate. 
c        betac       :  real vector giving the current value of the 
c                       candidate for fixed effects, betac(p).
c        ccluster    :  integer vector indicating the number of
c                       subjects in each cluster, ccluster(nsubject).
c        detlog      :  real used to save the log-determinant in a
c                       matrix inversion process.
c        dispcount   :  index. 
c        evali       :  integer indicator used in updating the state.
c        i           :  index. 
c        ii          :  index. 
c        iflagp      :  integer vector used to invert the of the lhs
c                       least square solution for the fixed effects,
c                       iflagp(p).
c        iflagb      :  integer vector used to invert the of the lhs
c                       least square solution for the random effects,
c                       iflagb(q).
c        isave       :  index. 
c        iscan       :  index. 
c        j           :  index. 
c        k           :  index. 
c        l           :  index.
c        prob        :  real vector used to update the cluster 
c                       structure, prob(nsubject+1).
c        quadf       :  real matrix used to save the bilinear product
c                       of random effects, quadf(q,q).
c        ni          :  integer indicator used in updating the state. 
c        ns          :  integer indicator used in updating the state. 
c        nscan       :  integer indicating the total number of MCMC
c                       scans.
c        runif       :  uniform random number generator.
c        seed1       :  seed for random number generation.
c        seed2       :  seed for random number generation.
c        seed3       :  seed for random number generation.
c        since       :  index.
c        skipcount   :  index. 
c        theta       :  real vector used to save randomnly generated
c                       random effects, theta(q).
c        thetac      :  real vector used to save randomnly generated
c                       random effects, thetac(q).
c        tmp1        :  real used to accumulate quantities. 
c        tmp2        :  real used to accumulate quantities.
c        workp1      :  real matrix used to update the fixed effects,
c                       workp1(p,p).
c        workp2      :  real matrix used to update the fixed effects,
c                       workp2(p,p).
c        workb1      :  real matrix used to update the random effects,
c                       workb1(q,q).
c        workb2      :  real matrix used to update the random effects,
c                       workb2(q,q).
c        workmh1     :  real vector used to update the fixed effects,
c                       workmh1(p*(p+1)/2).
c        workmh2     :  real vector used to update the random effects,
c                       workmh2(q*(q+1)/2).
c        workmh3     :  real vector used to update the random effects,
c                       workmh3(q*(q+1)/2).
c        workvp1     :  real vector used to update the fixed effects,
c                       workvp1(p).
c        workvb1     :  real vector used to update the random effects,
c                       workvb1(q).
c        workvb2     :  real vector used to update the random effects,
c                       workvb2(q).
c        xtx         :  real matrix givind the product X^tX, xtx(p,p).
c        xty         :  real vector used to save the product 
c                       Xt(Y-Zb), xty(p).
c        zty         :  real vector used to save the product 
c                       Zt(Y-Xbeta), zty(q).
c        ztz         :  real matrix used to save the product 
c                       ZtSigma^1Z, ztz(q,q).
c=======================================================================                  
      implicit none 

c+++++Data
      integer maxni,nrec,nsubject,nfixed,p,q,subject(nrec)
      integer datastr(nsubject,maxni+1),y(nrec)
      real*8 roffset(nrec),x(nrec,p),z(nrec,q)
      
c+++++Prior 
      integer nu0,murand,sigmarand
      real*8 aa0,ab0,a0b0(2),b0(p),prec(p,p),psiinv(q,q)
      real*8 sb(p),smu(q)
      real*8 tinv(q,q)      

c+++++MCMC parameters
      integer mpar,mcmc(5),nburn,nskip,nsave,ndisplay

c+++++Output
      real*8 acrate(2)
      real*8 cpo(nrec,2)
      real*8 randsave(nsave,q*(nsubject+1))
      real*8 thetasave(nsave,q+nfixed+q+(q*(q+1)/2)+2)

c+++++Current values of the parameters
      integer ncluster,ss(nsubject)
      real*8 alpha,beta(p),b(nsubject,q)
      real*8 betar(q),bclus(nsubject,q)
      real*8 mu(q),sigma(q,q),sigmainv(q,q)

c+++++Seeds
      integer seed(2),seed1,seed2

c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
c+++++External working space
c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

c+++++fixed effects
      integer iflagp(p)
      real*8 betac(p)
      real*8 xtx(p,p),xty(p)
      real*8 workmh1(p*(p+1)/2)
      real*8 workp1(p,p),workp2(p,p)
      real*8 workvp1(p)

c+++++random effects
      integer iflagb(q)
      real*8 quadf(q,q)
      real*8 thetac(q)
      real*8 zty(q),ztz(q,q)
      real*8 workb1(q,q),workb2(q,q)
      real*8 workmh2(q*(q+1)/2),workmh3(q*(q+1)/2)
      real*8 workvb1(q),workvb2(q)

c+++++DP
      integer ccluster(nsubject),cstrt(nsubject,nsubject)
      real*8 newtheta(q,mpar)
      real*8 prob(nsubject+mpar)
      real*8 theta(q)

c++++ model�s performance
      real*8 mc(5)
      real*8 betasave(p),bsave(nsubject,q)

c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
c+++++Internal working space
c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

c+++++General
      integer ii,i,jj,j,kk,k,ll,l
      integer evali 
      integer ihmssf,ni,ns
      integer ok,since,sprint 
      integer yij
      real*8 acrate2
      real*8 dpoiss
      real*8 eta,mean,offset,ytilde
      real*8 logcgkn,logcgko
      real*8 loglikn,logliko
      real*8 logpriorn,logprioro
      real*8 ratio
      real*8 tmp1,tmp2,tmp3

c+++++MCMC
      integer dispcount,isave,iscan,nscan,skipcount 

c+++++RNG and distributions
      real*8 rnorm
      real runif

c+++++DP
      real*8 eps,rbeta,weight
      parameter(eps=0.01)

c++++ model�s performance
      real*8 dbarc,dbar,dhat,pd,lpml

c+++++CPU time
      real*8 sec00,sec0,sec1,sec

c++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
c+++++Working space - ARS
c++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      integer maxn,maxl,maxu,maxeval
      parameter(maxn=2000,maxl=maxn-1,maxu=2+2*(maxn-1),maxeval=5000)
      real*8 lHb(maxl),lHm(maxl)
      real*8 lHl(maxl),lHr(maxl)
      real*8 uHb(maxu),uHm(maxu)
      real*8 uHl(maxu),uHr(maxu)
      real*8 uHpr(maxu)
      real*8 grid(maxn),fs(maxn),fps(maxn)

      integer accept,counter,err,neval
      real*8 fsx,fpsx,fsmax
      real*8 hlower,hupper
      real*8 luinf

      integer nstart,istart1,istart2
      parameter(nstart=5)
      real*8 scorea
      
c++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
c++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

c++++ parameters
      nburn=mcmc(1)
      nskip=mcmc(2)
      ndisplay=mcmc(3)
      murand=mcmc(4)
      sigmarand=mcmc(5)
      
      aa0=a0b0(1)
      ab0=a0b0(2)

c++++ set random number generator
      seed1=seed(1)
      seed2=seed(2)
      
      call setall(seed1,seed2)
     
c++++ cluster structure
      do i=1,nsubject
         ccluster(ss(i))=ccluster(ss(i))+1
         cstrt(ss(i),ccluster(ss(i)))=i
      end do
      
c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
c++++ start the MCMC algorithm
c+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      dbar=0.d0
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
c+++++++ fixed effects
c++++++++++++++++++++++++++++++++++

         if(nfixed.gt.0)then

            do i=1,p
               do j=1,p
                  xtx(i,j)=prec(i,j)
               end do
               xty(i)=sb(i)
            end do
            
            logliko=0.d0
            
            do i=1,nrec
               eta=0.d0
               offset=0.d0
               yij=y(i)               
               
               do j=1,p
                  eta=eta+x(i,j)*beta(j)
               end do
               
               do j=1,q
                  eta=eta+z(i,j)*b(subject(i),j) 
                  offset=offset+z(i,j)*b(subject(i),j) 
               end do
               
               eta=eta+roffset(i)
               offset=offset+roffset(i)

               ytilde=eta+(dble(yij)*exp(-eta)-1.d0)-offset
               
               do j=1,p
                  do k=1,p
                     xtx(j,k)=xtx(j,k)+x(i,j)*x(i,k)*exp(eta)
                  end do
                  xty(j)=xty(j)+x(i,j)*ytilde*exp(eta)
               end do
               
               mean=exp(eta)
               logliko=logliko+dpoiss(dble(yij),mean,1)
            end do
            
            call inverse(xtx,p,iflagp)
            
            do i=1,p
               tmp1=0.d0
               do j=1,p
                  tmp1=tmp1+xtx(i,j)*xty(j) 
               end do
               workvp1(i)=tmp1
            end do

            call rmvnorm(p,workvp1,xtx,workmh1,xty,betac)
           

c++++++++++ evaluating the candidate generating kernel

            call dmvn2(p,betac,workvp1,xtx,logcgko,
     &                 xty,workp1,workp2,iflagp)                 

c++++++++++ prior ratio

            logprioro=0.d0
            logpriorn=0.d0
            
            do i=1,p
               do j=1,p
                  logpriorn=logpriorn+(betac(i)-b0(i))* 
     &                       prec(i,j)      *
     &                      (betac(j)-b0(j))

                  logprioro=logprioro+(beta(i) -b0(i))* 
     &                       prec(i,j)      *
     &                      (beta(j) -b0(j))
               end do
            end do
            
            logpriorn=-0.5d0*logpriorn
            logprioro=-0.5d0*logprioro
            
c++++++++++ candidate generating kernel contribution

            do i=1,p
               do j=1,p
                  xtx(i,j)=prec(i,j)
               end do
               xty(i)=sb(i)
            end do

            loglikn=0.d0
            
            do i=1,nrec
               eta=0.d0
               offset=0.d0
               yij=y(i)               
               
               do j=1,p
                  eta=eta+x(i,j)*betac(j)
               end do
               
               do j=1,q
                  eta=eta+z(i,j)*b(subject(i),j) 
                  offset=offset+z(i,j)*b(subject(i),j) 
               end do

               eta=eta+roffset(i)
               offset=offset+roffset(i)

               ytilde=eta+(dble(yij)*exp(-eta)-1.d0)-offset
               
               do j=1,p
                  do k=1,p
                     xtx(j,k)=xtx(j,k)+x(i,j)*x(i,k)*exp(eta)
                  end do
                  xty(j)=xty(j)+x(i,j)*ytilde*exp(eta)
               end do
               mean=exp(eta)
               loglikn=loglikn+dpoiss(dble(yij),mean,1)
            end do

            call inverse(xtx,p,iflagp)

            do i=1,p
               tmp1=0.d0
               do j=1,p
                  tmp1=tmp1+xtx(i,j)*xty(j) 
               end do
               workvp1(i)=tmp1
            end do

c++++++++++ evaluating the candidate generating kernel

            call dmvn2(p,beta,workvp1,xtx,logcgkn,
     &                 xty,workp1,workp2,iflagp)                 
 
c++++++++++ mh step

            ratio=(loglikn-logliko+logcgkn-logcgko+
     &            logpriorn-logprioro)

            if(log(dble(runif())).lt.ratio)then
               acrate(1)=acrate(1)+1.d0
               do i=1,p
                  beta(i)=betac(i) 
               end do
            end if
         end if

        
c++++++++++++++++++++++++++++++++++         
c+++++++ random effects 
c++++++++++++++++++++++++++++++++++

c++++++++++++++++++++++++++++++
c+++++++ a) Polya Urn 
c++++++++++++++++++++++++++++++

         call cholesky(q,sigma,workmh2)

         do i=1,nsubject
         
            ns=ccluster(ss(i))
            ni=datastr(i,1) 

c++++++++++ observation in cluster with more than 1 element
             
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
                  tmp1=0.d0
                  do k=1,ni
                     yij=y(datastr(i,k+1))
                     
                     eta=0.d0
                     do l=1,p
                        eta=eta+x(datastr(i,k+1),l)*beta(l)
                     end do
		     do l=1,q
		        eta=eta+z(datastr(i,k+1),l)*bclus(j,l)
                     end do
                     
                     eta=eta+roffset(datastr(i,k+1))

                     mean=exp(eta)
                     tmp1=tmp1+dpoiss(dble(yij),mean,1)
                  end do
                  prob(j)=exp(log(dble(ccluster(j)))+
     &                        tmp1)
               end do

               do ll=1,mpar
                  do j=1,q
                     thetac(j)=rnorm(0.d0,1.d0)
                  end do
                  do j=1,q
                     tmp1=0.d0
                     do k=1,j
                        tmp1=tmp1*workmh2(ihmssf(j,k,q))*thetac(k) 
                     end do
                     theta(j)=mu(j)+tmp1
                  end do
               
                  tmp1=0.d0
                  do k=1,ni
                     yij=y(datastr(i,k+1))
                      
                     eta=0.d0
                     do l=1,p
                        eta=eta+x(datastr(i,k+1),l)*beta(l)
                     end do
                     do l=1,q
                        eta=eta+z(datastr(i,k+1),l)*theta(l)
                     end do
                     eta=eta+roffset(datastr(i,k+1))

                     mean=exp(eta)
                     tmp1=tmp1+dpoiss(dble(yij),mean,1)
                  end do

                  prob(ncluster+ll)=exp(log(alpha/dble(mpar))+tmp1)
                 
                  do j=1,q
                     newtheta(j,ll)=theta(j) 
                  end do
               end do  
               
               call simdisc(prob,nsubject+mpar,ncluster+mpar,evali)

               if(evali.le.ncluster)then
                  ss(i)=evali
                  ccluster(evali)=ccluster(evali)+1
                  cstrt(evali,ccluster(evali))=i
               end if   
               if(evali.gt.ncluster)then
                  ncluster=ncluster+1
                  ss(i)=ncluster
                  ccluster(ncluster)=1
                  cstrt(ncluster,ccluster(ncluster))=i
	          do j=1,q
	             bclus(ncluster,j)=newtheta(j,(evali-ncluster+1))
	          end do
               end if               
            end if

c++++++++++ subject in cluster with only 1 observation
             
            if(ns.eq.1)then
                
               since=ss(i)

               if(since.lt.ncluster)then
                   call relabel(i,since,nsubject,q,ncluster,
     &                          cstrt,ccluster,ss,bclus,theta)                   
	       end if

               ccluster(ncluster)=ccluster(ncluster)-1 
               ncluster=ncluster-1

               do j=1,ncluster
                  tmp1=0.d0
                  do k=1,ni
                     yij=y(datastr(i,k+1))
                     
                     eta=0.d0
                     do l=1,p
                        eta=eta+x(datastr(i,k+1),l)*beta(l)
                     end do
		     do l=1,q
		        eta=eta+z(datastr(i,k+1),l)*bclus(j,l)
                     end do
                     
                     eta=eta+roffset(datastr(i,k+1))

                     mean=exp(eta)
                     tmp1=tmp1+dpoiss(dble(yij),mean,1)
                  end do

                  prob(j)=exp(log(dble(ccluster(j)))+
     &                        tmp1)
               end do

               do ll=1,mpar
                  if(ll.eq.1)then
                     do j=1,q
                        theta(j)=b(i,j)
                     end do
                   else
                     do j=1,q
                        thetac(j)=rnorm(0.d0,1.d0)
                     end do
                     do j=1,q
                        tmp1=0.d0
                        do k=1,j
                           tmp1=tmp1*workmh2(ihmssf(j,k,q))*thetac(k) 
                        end do
                        theta(j)=mu(j)+tmp1
                     end do
                  end if
                  
                  tmp1=0.d0
                  do k=1,ni
                     yij=y(datastr(i,k+1))
                      
                     eta=0.d0
                     do l=1,p
                        eta=eta+x(datastr(i,k+1),l)*beta(l)
                     end do
                     do l=1,q
                        eta=eta+z(datastr(i,k+1),l)*theta(l)
                     end do
                     eta=eta+roffset(datastr(i,k+1))

                     mean=exp(eta)
                     tmp1=tmp1+dpoiss(dble(yij),mean,1)
                  end do
 
                  prob(ncluster+ll)=exp(log(alpha/dble(mpar))+tmp1)

                  do j=1,q
                     newtheta(j,ll)=theta(j) 
                  end do
               end do  

               call simdisc(prob,nsubject+mpar,ncluster+mpar,evali)

               if(evali.le.ncluster)then
                  ss(i)=evali
                  ccluster(evali)=ccluster(evali)+1
                  cstrt(evali,ccluster(evali))=i
               end if   
               if(evali.gt.ncluster)then
                  ncluster=ncluster+1
                  ss(i)=ncluster
                  ccluster(ncluster)=1
                  cstrt(ncluster,ccluster(ncluster))=i
	          do j=1,q
	             bclus(ncluster,j)=newtheta(j,(evali-ncluster+1))
	          end do
               end if               
	    end if
         end do

c++++++++++++++++++++++++++++++
c+++++++ b) Resampling step
c++++++++++++++++++++++++++++++

         do i=1,q
            betar(i)=0.d0
         end do

         acrate2=0.d0

         do ii=1,ncluster

c++++++++++ ARS sampligng for each element
            call rchkusr()
            
            do jj=1,q

c+++++++++++++ evaluate the function at some points to test derivatives

               counter=0
               grid(1)=-15.d0
               tmp1=30.d0/dble(nstart-1)
               do i=2,nstart
                  grid(i)=grid(i-1)+tmp1
               end do   

100            do kk=1,nstart
                  fs(kk)=0.d0               
                  fps(kk)=0.d0
                  logliko=0.d0
                  logprioro=0.d0                  
                  scorea=0.d0
                  
                  do i=1,q
                     theta(i)=bclus(ii,i)
                  end do   
                  theta(jj)=grid(kk)
            
                  do ll=1,ccluster(ii)
                     i=cstrt(ii,ll) 
                     ni=datastr(i,1)
                     do j=1,ni
                        eta=0.d0
                        offset=0.d0
                        yij=y(datastr(i,j+1))
                  
                        do k=1,p
                           eta=eta+x(datastr(i,j+1),k)*beta(k)
                        end do
                  
                        do k=1,q
                           eta=eta+z(datastr(i,j+1),k)*theta(k)
                        end do
                        eta=eta+roffset(datastr(i,j+1))

                        mean=exp(eta)
                        logliko=logliko+dpoiss(dble(yij),mean,1)

                        scorea=scorea+
     &                      z(datastr(i,j+1),jj)*(dble(yij)-mean)

                     end do
                  end do

                  do i=1,q
                     do j=1,q
                        logprioro=logprioro+(theta(i)-mu(i))* 
     &                            sigmainv(i,j)      *
     &                            (theta(j)-mu(j))
                     end do
                  end do
                  logprioro=-0.5d0*logprioro

                  do j=1,q
                     scorea=scorea-sigmainv(jj,j)*(theta(j)-mu(j))
                  end do
                  
                  fs(kk)=logliko+logprioro
                  fps(kk)=scorea
               end do        

c+++++++++++++ checking derivatives

               if(fps(1).le.0d0)then
                   counter=counter+1
                   do i=1,2
                      grid(i)=grid(i)-3.*sqrt(sigma(jj,jj))
                   end do
                   if(counter.lt.10)then
                     go to 100
                    else
                     call rexit("Error in deriv lim inf")
                   end if  
               end if

               if(fps(nstart).ge.0d0)then
                   counter=counter+1
                   do i=(nstart-1),nstart
                      grid(i)=grid(i)+3.*sqrt(sigma(jj,jj))
                   end do
                   if(counter.lt.10)then
                     go to 100
                    else
                     call rexit("Error in deriv lim sup")
                   end if  
               end if

c+++++++++++++ starting range

               neval=nstart
               go to 200
               
               istart1=1
               istart2=1
               
               do i=1,nstart
                  if(fps(i).gt.0.d0)istart1=i
               end do

               do i=nstart,1,-1
                  if(fps(i).lt.0.d0)istart2=i
               end do

c+++++++++++++ initialize the Hulls at nstart points

               grid(1)=grid(istart1)-sigma(jj,jj)
               grid(neval)=grid(istart2)+sigma(jj,jj)
               tmp1=(grid(neval)-grid(1))/dble(neval-1)
               do i=2,neval-1
                  grid(i)=grid(i-1)+tmp1 
               end do

               do kk=1,neval
                  fs(kk)=0.d0               
                  logliko=0.d0
                  logprioro=0.d0  
                  fps(kk)=0.d0
                  scorea=0.d0
                  
                  do i=1,q
                     theta(i)=bclus(ii,i)
                  end do   
                  theta(jj)=grid(kk)
            
                  do ll=1,ccluster(ii)
                     i=cstrt(ii,ll) 
                     ni=datastr(i,1)
                     do j=1,ni
                        eta=0.d0
                        offset=0.d0
                        yij=y(datastr(i,j+1))
                  
                        do k=1,p
                           eta=eta+x(datastr(i,j+1),k)*beta(k)
                        end do
                  
                        do k=1,q
                           eta=eta+z(datastr(i,j+1),k)*theta(k)
                        end do
                        eta=eta+roffset(datastr(i,j+1))
                        mean=exp(eta)
                        logliko=logliko+dpoiss(dble(yij),mean,1)
                        scorea=scorea+
     &                      z(datastr(i,j+1),jj)*(dble(yij)-mean)
     
                     end do
                  end do

                  do i=1,q
                     do j=1,q
                        logprioro=logprioro+(theta(i)-mu(i))* 
     &                            sigmainv(i,j)      *
     &                            (theta(j)-mu(j))
                     end do
                  end do

                  do j=1,q
                     scorea=scorea-sigmainv(jj,j)*(theta(j)-mu(j))
                  end do
                  
                  logprioro=-0.5d0*logprioro

                  fs(kk)=logliko+logprioro
                  fps(kk)=scorea
               end do        

200            continue

               call arsCompuHunD(neval,maxn,maxl,maxu,
     &                           lHb,lHm,
     &                           lHl,lHr,
     &                           uHb,uHm,
     &                           uHl,uHr,
     &                           uHpr,grid,fs,fps,fsmax)


c+++++++++++++ ARS algorithm
               counter=0
               accept=0
               
               do while(accept.eq.0.and.counter.lt.maxeval)
                  call rchkusr()
                  
                  counter=counter+1
                  call arsSampleHD(tmp1,neval,maxn,maxu,uHm,uHl,
     &                            uHr,uHpr)


                  call arsEvalHD(tmp1,neval,hlower,hupper,maxn,
     &                           maxl,maxu,
     &                           lHb,lHm,lHl,lHr,
     &                           uHb,uHm,uHl,uHr,uHpr,grid,fs)

                  luinf=log(dble(runif()))
                  hlower=hlower-fsmax
                  hupper=hupper-fsmax

c++++++++++++++++ squeezing test
                  if(tmp1.gt.grid(1).and.tmp1.lt.grid(neval))then
                     if(luinf.le.(hlower-hupper))accept=1
                  end if

                  
c++++++++++++++++ rejection test
                  if(accept.eq.0)then
                     do i=1,q
                        theta(i)=bclus(ii,i)
                     end do   
                     theta(jj)=tmp1

                     logliko=0.d0
                     logprioro=0.d0
                     scorea=0.d0
                     

                     do ll=1,ccluster(ii)
                        i=cstrt(ii,ll) 
                        ni=datastr(i,1)
                        do j=1,ni
                           eta=0.d0
                           offset=0.d0
                           yij=y(datastr(i,j+1))
                   
                           do k=1,p
                              eta=eta+x(datastr(i,j+1),k)*beta(k)
                           end do
                   
                           do k=1,q
                              eta=eta+z(datastr(i,j+1),k)*theta(k)
                           end do
                           eta=eta+roffset(datastr(i,j+1))
 
                           mean=exp(eta)
                           logliko=logliko+dpoiss(dble(yij),mean,1)

                           scorea=scorea+
     &                      z(datastr(i,j+1),jj)*(dble(yij)-mean)
                        end do
                     end do

                     do i=1,q
                        do j=1,q
                           logprioro=logprioro+(theta(i)-mu(i))* 
     &                            sigmainv(i,j)      *
     &                            (theta(j)-mu(j))
                        end do
                     end do
                     logprioro=-0.5d0*logprioro

                     do j=1,q
                        scorea=scorea-sigmainv(jj,j)*(theta(j)-mu(j))
                     end do
                  
                     fsx=logliko+logprioro
                     fpsx=scorea

                     if(luinf.le.(fsx-fsmax-hupper))accept=1
                  end if

                  if(accept.eq.0)then
                    if((neval+1).le.maxn)then 
                       call arsUpdateSD(neval,maxn,grid,fs,fps,tmp1,
     &                               fsx,fpsx,fsmax,err)
                       if(err.eq.0)then

                          call arsCompuHunD(neval,maxn,maxl,maxu,
     &                           lHb,lHm,lHl,lHr,uHb,uHm,uHl,uHr,
     &                           uHpr,grid,fs,fps,fsmax)
                       end if 
                    end if
                  end if 

                  if(accept.eq.0.and.counter.eq.maxeval)then
                    call rexit("Maximum # of evaluations reached")
                  end if
               end do
               bclus(ii,jj)=tmp1
            end do

            do i=1,q
               theta(i)=bclus(ii,i)
               betar(i)=betar(i)+bclus(ii,i)
            end do

            do jj=1,ccluster(ii)
               i=cstrt(ii,jj) 
               do j=1,q
                  b(i,j)=theta(j)
               end do
            end do
         end do


c++++++++++++++++++++++++++++++++++         
c+++++++ Base line distribution
c++++++++++++++++++++++++++++++++++

c+++++++ check if the user has requested an interrupt
         call rchkusr()

         if(murand.eq.1)then
            do i=1,q
               do j=1,q
                  workb1(i,j)=(sigmainv(i,j)*dble(ncluster))+psiinv(i,j)
               end do
            end do

            call inverse(workb1,q,iflagb)

            do i=1,q
               tmp1=0.d0
               do j=1,q
                  tmp1=tmp1+sigmainv(i,j)*betar(j)
               end do
               workvb1(i)=smu(i)+tmp1
            end do
     
            do i=1,q
               tmp1=0.d0
               do j=1,q
                  tmp1=tmp1+workb1(i,j)*workvb1(j)
               end do
               workvb2(i)=tmp1
            end do
          
            call rmvnorm(q,workvb2,workb1,workmh2,workvb1,theta)

            do i=1,q
               mu(i)=theta(i)
            end do
         end if

c+++++++ check if the user has requested an interrupt
         call rchkusr()

         if(sigmarand.eq.1)then                    
            do i=1,q
               do j=1,q
                  quadf(i,j)=0.d0
               end do
            end do

            do i=1,ncluster
               do j=1,q
                  do k=1,q
                     quadf(j,k)=quadf(j,k)+               
     &                          (bclus(i,j)-mu(j))*(bclus(i,k)-mu(k))                   
                  end do
               end do
            end do

            do i=1,q
               do j=1,q
                  quadf(i,j)=quadf(i,j)+tinv(i,j)
               end do
            end do

            call riwishart(q,nu0+ncluster,quadf,workb1,workb2,workvb1,
     &                     workmh2,workmh3,iflagb)

            do i=1,q
               do j=1,q
                  sigma(i,j)=quadf(i,j)
                  sigmainv(i,j)=workb1(i,j)
               end do
            end do
         end if   

c++++++++++++++++++++++++++++++++++         
c+++++++ Precision parameter
c++++++++++++++++++++++++++++++++++
         if(aa0.gt.0.d0)then
            call samalph(alpha,aa0,ab0,ncluster,nsubject)
         end if 



c++++++++++++++++++++++++++++++++++         
c+++++++ save samples
c++++++++++++++++++++++++++++++++++         
         
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

               do i=1,ncluster
                  prob(i)=dble(ccluster(i))/(alpha+dble(nsubject))
               end do
               prob(ncluster+1)=alpha/(alpha+dble(nsubject))

               call simdisc(prob,nsubject+mpar,ncluster+1,evali)
               
               if(evali.le.ncluster)then
                  do j=1,q
                     theta(j)=bclus(evali,j)
                  end do
               end if
               if(evali.gt.ncluster)then
                  call rmvnorm(q,mu,sigma,workmh2,workvb1,theta)
               end if
               
               do i=1,q
                  k=k+1
                  randsave(isave,k)=theta(i) 
               end do

c+++++++++++++ functional parameters
               
               tmp1=rbeta(1.d0,alpha+dble(nsubject))
               do i=1,q
                  betar(i)=tmp1*theta(i)
               end do
               tmp2=tmp1
               weight=(1.d0-tmp1)
               
               do while((1.d0-tmp2).gt.eps)
                  tmp3=rbeta(1.d0,alpha+dble(nsubject))
                  tmp1=weight*tmp3
                  weight=weight*(1.d0-tmp3)

                  do i=1,ncluster
                     prob(i)=dble(ccluster(i))/(alpha+dble(nsubject))
                  end do
                  prob(ncluster+1)=alpha/(alpha+dble(nsubject))

                  call simdisc(prob,nsubject+1,ncluster+1,evali)
               
                  if(evali.le.ncluster)then
                     do j=1,q
                        theta(j)=bclus(evali,j)
                     end do
                  end if
                  if(evali.gt.ncluster)then
                     call rmvnorm(q,mu,sigma,workmh2,workvb2,theta)
                  end if

                  do i=1,q
                     betar(i)=betar(i)+tmp1*theta(i)
                  end do
                  tmp2=tmp2+tmp1
               end do

               do i=1,ncluster
                  prob(i)=dble(ccluster(i))/(alpha+dble(nsubject))
               end do
               prob(ncluster+1)=alpha/(alpha+dble(nsubject))

               call simdisc(prob,nsubject+1,ncluster+1,evali)
               
               if(evali.le.ncluster)then
                  do j=1,q
                     theta(j)=bclus(evali,j)
                  end do
               end if
               if(evali.gt.ncluster)then
                  call rmvnorm(q,mu,sigma,workmh2,workvb2,theta)
               end if
               
               tmp1=weight

               do i=1,q
                  betar(i)=betar(i)+tmp1*theta(i)
               end do

c+++++++++++++ regression coefficients

               do i=1,q
                  thetasave(isave,i)=betar(i)
               end do

               if(nfixed.gt.0)then
                  do i=1,p
                     thetasave(isave,q+i)=beta(i)
                     betasave(i)=betasave(i)+beta(i)                     
                  end do
               end if   

c+++++++++++++ baseline mean

               do i=1,q
                  thetasave(isave,q+nfixed+i)=mu(i)
               end do

c+++++++++++++ baseline covariance

               k=0
               do i=1,q
                  do j=i,q
                     k=k+1
                     thetasave(isave,q+nfixed+q+k)=sigma(i,j)
                  end do
               end do

c+++++++++++++ cluster information
               k=(q*(q+1)/2)  
               thetasave(isave,q+nfixed+q+k+1)=ncluster
               thetasave(isave,q+nfixed+q+k+2)=alpha

c+++++++++++++ cpo
               dbarc=0.d0
               do i=1,nrec
                  yij=y(i)
                  eta=0.d0
                  if(nfixed.gt.0)then
                     do j=1,p
                        eta=eta+x(i,j)*beta(j)
                     end do
                  end if   
		  do j=1,q
		     eta=eta+z(i,j)*b(subject(i),j)
                  end do
                  eta=eta+roffset(i)               
                  mean=exp(eta)
                  
                  tmp1=dpoiss(dble(yij),mean,0)
                  cpo(i,1)=cpo(i,1)+1.0d0/tmp1
                  cpo(i,2)=cpo(i,2)+tmp1                  
                  
                  tmp1=dpoiss(dble(yij),mean,1)
                  dbarc=dbarc+tmp1
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
      
      acrate(1)=acrate(1)/dble(nscan)    
      acrate(2)=1.d0
      
      do i=1,nrec
         cpo(i,1)=dble(nsave)/cpo(i,1)
         cpo(i,2)=cpo(i,2)/dble(nsave)                                    
      end do

      do i=1,p
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
         yij=y(i)
         eta=0.d0
         do j=1,p
            eta=eta+x(i,j)*betasave(j)
         end do
	 do j=1,q
	   eta=eta+z(i,j)*bsave(subject(i),j)
         end do
         eta=eta+roffset(i)                   
         
         mean=exp(eta)
         dhat=dhat+dpoiss(dble(yij),mean,1)
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
      