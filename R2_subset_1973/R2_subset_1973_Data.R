



#---------------------------------------------------------------
# 
#---------------------------------------------------------------
Regress_P37_EDEN = function(
  file.p37  = 'P37_NAVD_cm_1973-1-1_2017-12-31.csv', # 1973 - 2017
  file.eden = 'EDEN_R2_Subset_1973_Stage_UTM.csv',   # 1991 - 2017
  file.out  = 'EDEN_R2_Subset_StageNAVDcm_1973_2017.csv'
) {

  # Date, round.navd_cm..2.
  df.p37 = read.csv( file.p37, header = TRUE, as.is = TRUE )
  i.1991 = which( as.Date( df.p37 $ Date ) == as.Date( '1991-1-1' ) )
  N      = nrow( df.p37 )

  P37 = df.p37[ i.1991 : N, 'round.navd_cm..2.' ]

  # Date, Cell_14_191, Cell_17_188, Cell_8_172, ...
  df.eden = read.csv( file.eden, header = TRUE, as.is = TRUE )

  if ( length( P37 ) != nrow( df.eden ) ) {
    stop( "length( P37 ) != nrow( df.eden )" )
  }

  # Linear regression of observed P37 onto EDEN at the model cells
  L = list()
  for ( col in names( df.eden[ 2 : ncol( df.eden ) ] ) ) {
    L[[ col ]] = lm( P37 ~ df.eden[ , col ] )
  }

  #-----------------------------------------------------
  if ( is.null( dev.list() ) ) {
    newPlot( mfrow = c( 7, 5 ), mar = c(2, 2, 1, 1) )
  }

  for ( col in names( L ) ) {
    plot( df.eden[ , col ], P37, pch = 19, cex = 0.5 )
    abline( L[[ col ]], col = 'red', lwd = 2 )
    mtext( col, line = -1.3, cex = 1 )
  } # plot(0,0,axes=FALSE)
  
  # Create output data frame and data vector 
  df.out = data.frame( Date = as.Date( df.p37 $ Date ) )
  v      = vector( 'double', N )
  i.end  = i.1991 - 1

  # Regress observed P37 onto the missing times at each cell
  for ( col in names( L ) ) {
    lmCoef = coef( L[[ col ]] ) # 2-vector of (Intercept, slope)
    v[ 1 : i.end ]  = lmCoef[1] + P37[ 1 : i.end ] * lmCoef[2]
    v[ i.1991 : N ] = df.eden[ , col ]

    # Add to data.frame
    df.out[ col ] = round( v, 2 )
  }
  
  #-----------------------------------------------------
  # Plot results
  Date = as.Date( df.out $ Date )
  for ( col in names( L ) ) {
    plot( Date, df.out[ , col ], type = 'l' )
    abline( h = 0, col = 'red' )
    mtext( col, line = -1.3, cex = 1 )
  }
  # plot(0,0,axes=FALSE)

  write.csv( df.out, file.out, quote = FALSE, row.names = FALSE )
}

#---------------------------------------------------------------
# Convert P37 stage data from NGVD29 ft to NAVD88 cm
#---------------------------------------------------------------
ConvertP37 = function(
  file.in  = 'P37_1973-1-1_2017-12-31.csv',
  file.out = 'P37_NAVD_cm_1973-1-1_2017-12-31.csv'
) {

  df = read.csv( file.in, skip = 8, header = T, as.is = T, na.strings = 'null')

  Date = as.Date( df $ date )

  ngvd_cm = df $ fill_cm

  newPlot()
  plot( Date, ngvd_cm, type = 'l', lwd = 2, xlab = '' )
  
  ngvd.to.navd.ft = -1.55
  ngvd.to.navd.cm = ngvd.to.navd.ft * 30.48

  navd_cm = ngvd_cm + ngvd.to.navd.cm

  lines( Date, navd_cm, lwd = 2, col = 'red' )

  df.out = data.frame( Date, round( navd_cm, 2 ) )
  write.csv( df.out, file = file.out, quote = FALSE, row.names = FALSE )
}
