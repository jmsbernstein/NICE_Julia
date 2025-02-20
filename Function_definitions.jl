# Function Definitions required to run createPrandom_and_parameters2consumption

function backstop(Th,RL,pw,du,dd,tau)
  T = 60
  I = 12
  taut = convert(Int,(tau-1995)/10)
  p0 = pw.*RL
  pb = zeros(nsample,I,T) # note order of dimensions!
  pb[:,:,1] = p0
  for t = 2:taut
    pb[:,:,t] = Th*p0 + (1-du)*(pb[:,:,t-1]-Th*p0)
  end
  for t = (taut+1):T
    pb[:,:,t] = pb[:,:,t-1]*dd
  end
  return pb
end

function sig(gT,delsig,sighisT,adj15,Y0,E0)
  T = 60
  I = 12
  sigma = zeros(nsample,I,T) # note order of dimensions
  E000 = E0/1000
  sigma[:,:,1] = repmat(E000./Y0,nsample)
  sigma[:,:,2] = broadcast(*,broadcast(*,sigma[:,:,1],exp(sighisT*10)),adj15)
  compdelsig = ((1.-broadcast(.^,1-delsig,2:T)')./delsig).-1 # creates all the compounding of delsig broadcast(.^,1-delsig,[2:T])'
  for t = 3:T
    G_ = exp((ones(nsample,I)*(t-2)*gT + (sighisT.-gT)*compdelsig[1,t-2])*10) #sum(compdelsig[1:t-1]))*10)
    sigma[:,:,t] = sigma[:,:,2].*G_
  end
  return sigma
end

# T = 60
# compdelsig = ((1.-broadcast(.^,1-delsig,[2:T])')./delsig).-1
# compdelsig[1,5]
function population(Pop0,poprates)
  T = 60
  I = 12
  L = zeros(nsample,I,T) # note order of dimensions
  L[:,:,1] = repmat(Pop0,nsample)
  for t = 2:31
    L[:,:,t] = L[:,:,t-1].*exp(repmat(poprates[t-1,:]'*10,nsample))
  end
  for t = 32:T
    L[:,:,t] = L[:,:,31]
  end
  return L
end

function forcingEx(Fex2000,Fex2100)
  T = 60
  Fex = zeros(1,T)
  Fex = Fex2000*ones(1,T) + 0.1*(0:T-1)'*(Fex2100-Fex2000)
  for t = 12:T
    Fex[t] = 0.3
  end
  return Fex
end

function tfactorp(A0,gy0,tgl,delA,gamma,Crate,Cratio,y0)
  T = 60
  I = 12
  tfp = zeros(nsample,I,T) # note order of dimensions
  tfp[:,:,1] = repmat(A0,nsample)
  tfp[:,:,2] = broadcast(*,tfp[:,:,1],exp(10*(1-gamma)*gy0))
  compdelA = repmat(exp(-delA*(1:(T-2))'),nsample) # creates all the compounded delA values
  gtUS = (1-gamma)*(tgl*ones(nsample,T-2) + (repmat(gy0[:,1],1,(T-2)) - tgl*ones(nsample,T-2)).*compdelA) # growth rates in US, periods 3 to 60
  cgtus = cumsum(gtUS,2)
  tfp[:,1,3:T] = tfp[:,1,2].*exp(cgtus.*10) # USA is correct
  fac = zeros(nsample,I-1)
  for i = 1:nsample
    fac[i,:] = log(y0[1]./y0[2:I]') + log(Cratio) + 10*(gy0[i,1].-gy0[i,2:I])'
  end
  k = (1-Crate).^(0:T-3)'
  kR = zeros(nsample,I-1,T-2)
  for i = 1:nsample
    kR[i,:,:] = Crate*(1-gamma)*0.1*(fac[i,:]''*k)
  end
  gtUS_ = permutedims(cat(3,gtUS,gtUS,gtUS,gtUS,gtUS,gtUS,gtUS,gtUS,gtUS,gtUS,gtUS),[1 3 2]) # adds third dimension to gtUS (manual at the moment since I-1 = 11 is fixed)
  gtR = gtUS_ + kR
  cgtR = cumsum(gtR,3)
  tfp[:,2:I,3:T] = tfp[:,2:I,2].*exp(10*cgtR)
  return tfp
end

function landuse(EL0,delL)
  T = 60
  EL = EL0'.*(1-delL).^(0:T-1)'
  return EL
end

function elasticity2attribution(e, shares)
  # damage attribution vector for given income elasticity of damage and income distribution
	da = shares.^e
  d = zeros(5,12)
	for i = 1:12
		d[:,i] = da[:,i]/sum(da[:,i])
	end
	return d
end

function damage(temp, psi)
  # maps atmospheric temperature to damage
	#calculate all regions' damage term
	D = (psi[1, :].*temp + psi[2, :].*temp^2 + (psi[3,:].*temp).^7).*0.01
end

function tempforcing(mat, fex, xi, transition, stock)
  # temperature cycle forced by carbon mass
	#evaluate temperature flow
	forcing = xi[2]*(xi[1]*log2((mat+0.000001)/xi[6])+fex)
	T = stock*transition + [1 0]*forcing
end

function Mflow(stock, flow, transition)
  # carbon cycle forced by emissions
	#evaluate the carbon flow
	M = stock*transition + 10*[1 0 0]*flow
end

function fromtax(tax,P,Tm)
# this is the NICE model
# maps the carbon tax (length(tax) < Tm) to consumption (Tmx12x5)
	#consumption and capital
	c = Array(Float64, Tm, 12, 5)
  cbar = Array(Float64, Tm, 12)
	K = Array(Float64, Tm, 12)
	K[1,:] = P.K0
  #temperature emissions and carbon mass
	T = Array(Float64, Tm, 2)
	T[1, :] = P.T0
	T[2, :] = P.T1
	E = Array(Float64, Tm, 12)
	M = Array(Float64, Tm, 3)
	M[1, :] = P.M0
	M[2, :] = P.M1
	#savings and tax
	s1 = P.para[4]/(1+P.para[1])^10
	S = ones(Tm,12).*s1
  # TAX =  [0; tax; maximum(P.pb,2)[(length(tax)+2):end]]
  TAX = maximum(P.pb,2)
	TAX[1] = 0
	TAX[2:length(tax)+1] = tax
	#mitition rate, abatement cost, damage, deflator
	mu = Array(Float64, Tm, 12)
	lam = Array(Float64, Tm, 12)
	D = Array(Float64, Tm, 12)
	AD = Array(Float64, Tm, 12)
	#output
	Y = Array(Float64, Tm, 12)
	Q = Array(Float64, Tm, 12)
	#Period 1
	mu[1, :] = max(min((TAX[1]./P.pb[1,:]).^(1/(P.th2-1)),1),0) # mu between 0 and 1 element by element
	lam[1, :] = max(min(P.th1[1, :].*mu[1, :].^P.th2,1),0) # lam between 0 and 1 element by element
	D[1, :] = damage(T[1,1],P.psi)
	AD[1, :] = (1-lam[1, :])./(1+D[1, :])
	Y[1, :] = P.A[1,:].*P.L[1,:].^(1-P.para[4]).*K[1,:].^P.para[4]
	Q[1,:] = AD[1,:].*Y[1,:]
	cbar[1,:] = (1-S[1, :]).*Q[1, :]./P.L[1, :]
	#quintile consumptions period 1
	for i = 1:5
		c[1,:,i] = 5*cbar[1,:].*((1+D[1, :]).*P.q[i, :] - D[1, :].*P.d[i, :])
	end
  # Period 2
	K[2, :] = max(S[1,:].*Q[1, :]*10,0) # prevent negative capital (note, this will not bind at the optimum, but prevents the optmization from crashing)
	Y[2, :] = P.A[2,:].*P.L[2,:].^(1-P.para[4]).*K[2,:].^P.para[4]
	mu[2, :] =  max(min((TAX[2]./P.pb[2,:]).^(1/(P.th2-1)),1),0)
	E[2, :] = (1 - mu[2, :]).*P.sigma[2, :].*Y[2, :]
	M[3, :] = Mflow(M[2,:]', sum(E[2, :] + P.EL[2, :]), P.TrM)
	lam[2, :] = max(min(P.th1[2, :].*mu[2, :].^P.th2,1),0)
	D[2, :] = damage(T[2, 1], P.psi)
	AD[2, :] = (1-lam[2, :])./(1+D[2, :])
	Q[2,:] = AD[2,:].*Y[2,:]
	cbar[2,:] = (1-S[2, :]).*Q[2, :]./P.L[2, :]
	#quintile consumptions period 2
	for i = 1:5
		c[2,:,i] = max(5*cbar[2,:].*((1+D[2, :]).*P.q[i, :] - D[2, :].*P.d[i, :]), P.tol)
	end
	K[3, :] = max(S[2, :].*Q[2, :].*10,0) # prevent negative capital (note, this will not bind at the optimum, but prevents the optmization from crashing)
	#periods 3 to Tm-1
	for t = 3:(Tm - 1)
    Y[t,:] = P.A[t,:].*P.L[t,:].^(1-P.para[4]).*K[t,:].^P.para[4]
		mu[t, :] =  max(min((TAX[t]./P.pb[t,:]).^(1/(P.th2-1)),1),0)
		lam[t, :] = max(min(P.th1[t, :].*mu[t, :].^P.th2,1),0)
		E[t, :] = (1 - mu[t, :]).*P.sigma[t, :].*Y[t, :]
		M[t+1, :] = Mflow(M[t,:]', sum(E[t, :] + P.EL[t, :]), P.TrM)
		Mbar = (M[t+1, 1] +M[t, 1])/2
		T[t, :] = tempforcing(Mbar, P.Fex[t], P.xi, P.TrT, T[t-1, :]')
		D[t, :] = damage(T[t, 1], P.psi)
		AD[t, :] = (1-lam[t, :])./(1+D[t, :])
		Q[t, :] = AD[t, :].*Y[t, :]
		cbar[t,:] = (1-S[t, :]).*Q[t, :]./P.L[t, :]
		for i = 1:5
			c[t, :, i] = max(5*cbar[t,:].*((1+D[t, :]).*P.q[i, :] - D[t, :].*P.d[i, :]), P.tol)
		end
		K[t+1, :] = max(S[t, :].*Q[t, :]*10,0) # prevent negative capital (note, this will not bind at the optimum, but prevents the optmization from crashing)
	end
  # Period Tm
  Y[Tm, :] = P.A[Tm,:].*P.L[Tm,:].^(1-P.para[4]).*K[Tm,:].^P.para[4]
	mu[Tm, :] =  max(min((TAX[Tm]./P.pb[Tm,:]).^(1/(P.th2-1)),1),0)
	lam[Tm, :] = max(min(P.th1[Tm, :].*mu[Tm, :].^P.th2,1),0)
	T[Tm, :] = tempforcing(M[Tm, 1], P.Fex[Tm], P.xi, P.TrT, T[Tm-1, :]')
	D[Tm, :] = damage(T[Tm, 1], P.psi)
	AD[Tm, :] = (1-lam[Tm, :])./(1+D[Tm, :])
	Q[Tm, :] = AD[Tm, :].*Y[Tm, :]
	cbar[Tm,:] = (1-S[Tm, :]).*Q[Tm, :]./P.L[Tm, :]
	for i = 1:5
		c[Tm, :, i] =  max(5*cbar[Tm,:].*((1+D[Tm, :]).*P.q[i, :] - D[Tm, :].*P.d[i, :]), P.tol)
	end
	return c,K,T,E,M,mu,lam,D,AD,Y,Q,cbar
end

function welfare(c, L, rho, eta, Tm)
	R = 1./(1+rho).^(10.*(0:(Tm-1)))
	A = Array(Float64, Tm, 12, 5)
	for i = 1:5
		A[:,:,i] = 0.2*L[1:Tm,:].*c[:,:,i].^(1-eta)
	end
	B = squeeze(sum(sum(A,3),2),3)'
	W = (B*R/(1-eta))[1]
  return W
end

function tax2welfare(tax, P, rho, eta, Tm)
	c = fromtax(tax, P, Tm)[1]
	W = welfare(c, P.L, rho, eta, Tm)
  return W
end

function tax2expectedwelfare(tax, P, rho, eta, nu, Tm, tm, lm, idims)
  c = zeros(Tm,12,5,nsample) # will contain per capita consumption at time t, in region I, in quintile q, for random draw n
  for i = 1:idims
      c[:,:,:,i] = fromtax(tax[1:tm],P[i],Tm)[1] # only consider tm length since we want to create a tax vector of particular length
  end
  for i = idims+1:length(P) # NB length(P) = nsample
      c[:,:,:,i] = fromtax([tax[1:lm];tax[tm+1:end]],P[i],Tm)[1]
  end
  R = 1./(1+rho).^(10.*(0:(Tm-1))) # discount factors for each time period
  D = zeros(Tm,12,5,nsample)
  # Convert consumption to per capita discounted utility at time t, in region I (weighted by population), in quintile q, for random draw n
  for t = 1:Tm
    D[t,:,:,:] = ((c[t,:,:,:].^(1-eta)).*R[t])./(1-eta)
  end
  D_ = zeros(Tm,12,5,nsample)
  for i = 1:nsample
    D_[:,:,:,i] = D[:,:,:,i].*cat(3,P[i].L[1:Tm,:],P[i].L[1:Tm,:],P[i].L[1:Tm,:],P[i].L[1:Tm,:],P[i].L[1:Tm,:])
  end
  D = D_
  # Now sum over quintiles to get per capita discounted utility at time t, in region I, in random draw n
  B1 = sum(D,3)
  # Now sum over regions to get per capita discounted utility at time t, in random draw n
  B2 = sum(B1,2)
  # Now sum over time to get per capita lifetime discounted utility in random draw n, and undo the concavity to get a "certainty equivalent" consumption measure
  B3 = (sum(B2,1).*(1-eta)).^(1/(1-eta))
  # Now sum over random draws with the risk adjustment (nu) to get total world welfare (normalizing by nsample)
  W = sum(B3.^(1-nu))*(1/(1-nu))./nsample
#   W = (0.33*B3[1,1,1,1].^(1-nu) + 0.67*B3[1,1,1,2].^(1-nu))*(1/(1-nu)) # Test for unequal probabilities effect on learning...
  return W,c
end

function welfare2c_bar(W, L, rho, eta, nu, Tm)
  R = 1./(1+rho).^(10.*(0:(Tm-1))) # discount factors for each time period
  D = sum(R.*L)
  cbar = (((1-nu)*W)^(1/(1-nu)))/((D)^(1/(1-eta)))
  return cbar
end
