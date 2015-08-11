Build_TMB_Fn <-
function( TmbData, TmbDir, Version, VesselConfig, CovConfig, Q_Config, RhoConfig=c("Beta1"=0,"Beta2"=0,"Epsilon1"=0,"Epsilon2"=0), Aniso, ConvergeTol=2, Parameters="generate", Random="generate", Map="generate" ){

  # Local functions
  boundsifpresent_fn = function( par, map, name, lower, upper, bounds ){
    if( name %in% names(par) ){
      bounds[grep(name,names(par)),c('Lower','Upper')] = c(lower,upper)
    }
    return( bounds )
  }
  
  # Parameters
  if( length(Parameters)==1 && Parameters=="generate" ) Parameters = Param_Fn( Version=Version, DataList=TmbData, RhoConfig=RhoConfig )

  # Which are random
  if( length(Random)==1 && Random=="generate" ) Random = c("Epsiloninput1_st", "Omegainput1_s", "Epsiloninput2_st", "Omegainput2_s", "nu1_v", "nu2_v", "nu1_vt", "nu2_vt")
  if( RhoConfig[["Beta1"]]!=0 ) Random = c(Random, "beta1_t")
  if( RhoConfig[["Beta2"]]!=0 ) Random = c(Random, "beta2_t")

  # Which parameters are turned off
  if( length(Map)==1 && Map=="generate" ) Map = Make_Map( Version=Version, TmbData=TmbData, VesselConfig=VesselConfig, CovConfig=CovConfig, Q_Config=Q_Config, RhoConfig=RhoConfig, Aniso=Aniso)

  # Build object
  dyn.load( paste0(TmbDir,"/",dynlib(Version)) )                                     # random=Random, 
  Obj <- MakeADFun(data=TmbData, parameters=Parameters, hessian=FALSE, map=Map, random=Random, inner.method="newton")
  Obj$control <- list(trace=1, parscale=1, REPORT=1, reltol=1e-12, maxit=100)

  # Declare upper and lower bounds for parameter search
  Bounds = matrix( NA, ncol=2, nrow=length(Obj$par), dimnames=list(names(Obj$par),c("Lower","Upper")) )
  Bounds[,'Lower'] = rep(-50, length(Obj$par))
  Bounds[,'Upper'] = rep( 50, length(Obj$par))
  Bounds[grep("logsigmaV",names(Obj$par)),'Lower'] = log(0.01)
  Bounds[grep("logsigmaVT",names(Obj$par)),'Lower'] = log(0.01)
  Bounds[grep("logtau",names(Obj$par)),'Upper'] = 10   # Version < v2i
  Bounds[grep("logeta",names(Obj$par)),'Upper'] = log(1/(1e-2*sqrt(4*pi))) # Version >= v2i: Lower bound on margSD = 1e-4
  Bounds[grep("SigmaM",names(Obj$par)),'Upper'] = 10 # ZINB can crash if it gets > 20
  Bounds = boundsifpresent_fn( par=Obj$par, name="gamma1", lower=-20, upper=20, bounds=Bounds)
  Bounds = boundsifpresent_fn( par=Obj$par, name="gamma2", lower=-20, upper=20, bounds=Bounds)
  Bounds = boundsifpresent_fn( par=Obj$par, name="lambda1", lower=-20, upper=20, bounds=Bounds)
  Bounds = boundsifpresent_fn( par=Obj$par, name="lambda2", lower=-20, upper=20, bounds=Bounds)
  Bounds = boundsifpresent_fn( par=Obj$par, name="Beta_rho1", lower=-1, upper=1, bounds=Bounds)
  Bounds = boundsifpresent_fn( par=Obj$par, name="Beta_rho2", lower=-1, upper=1, bounds=Bounds)
  Bounds = boundsifpresent_fn( par=Obj$par, name="Epsilon_rho1", lower=-1, upper=1, bounds=Bounds)
  Bounds = boundsifpresent_fn( par=Obj$par, name="Epsilon_rho2", lower=-1, upper=1, bounds=Bounds)

  # Change convergence tolerance
  Obj$env$inner.control$step.tol <- c(1e-8,1e-12,1e-15)[ConvergeTol] # Default : 1e-8  # Change in parameters limit inner optimization
  Obj$env$inner.control$tol10 <- c(1e-6,1e-8,1e-12)[ConvergeTol]  # Default : 1e-3     # Change in pen.like limit inner optimization
  Obj$env$inner.control$grad.tol <- c(1e-8,1e-12,1e-15)[ConvergeTol] # # Default : 1e-8  # Maximum gradient limit inner optimization

  # Return stuff
  Return = list("Obj"=Obj, "Upper"=Bounds[,'Upper'], "Lower"=Bounds[,'Lower'], "Parameters"=Parameters, "Map"=Map, "Random"=Random)
  return( Return )
}