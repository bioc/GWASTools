# Methods for GdsGenotypeReader

GdsGenotypeReader <- function(filename, ...) {
  if (missing(filename)) stop("filename is required")
  new("GdsGenotypeReader", GdsReader(filename), ...)
}

setValidity("GdsGenotypeReader",
    function (object) {
      # check that dimensions and variables are as expected
      
      # check that variables are snpID, chromosome, position, scanID, genotype
      if (!hasVariable(object, object@snpIDvar)) {
        return(paste("variable", object@snpIDvar, "not found in", object@filename))
      }
      if (!hasVariable(object, object@chromosomeVar)) {
        return(paste("variable", object@chromosomeVar, "not found in", object@filename))
      } 
      if (!hasVariable(object, object@positionVar)) {
        return(paste("variable", object@positionVar, "not found in", object@filename))
      }
      if (!hasVariable(object, object@scanIDvar)) {
        return(paste("variable", object@scanIDvar, "not found in", object@filename))
      }
      if (!hasVariable(object, object@genotypeVar)) {
        return(paste("variable", object@genotypeVar, "not found in", object@filename))
      }
      
      # check that chromosome and position have same dimension as snpID
      snpDim <- getDimension(object, object@snpIDvar)
      chrDim <- getDimension(object, object@chromosomeVar)
      if (chrDim != snpDim) {
        return(paste("variable", object@chromosomeVar, "has incorrect dimension"))
      }
      posDim <- getDimension(object, object@positionVar)
      if (posDim != snpDim) {
        return(paste("variable", object@positionVar, "has incorrect dimension"))
      }
      
      # check that genotype has dimensions [snpID,scanID]
      scanDim <- getDimension(object, object@scanIDvar)
      genoDim <- getDimension(object, object@genotypeVar)
      if (length(genoDim) != 2 |
          !all(genoDim == c(snpDim, scanDim))) {
        return(paste("variable", object@genotypeVar, "has incorrect dimensions"))
      }      

      TRUE
    })

           
# snp and scan are vectors of the format c(start, count)
# count = -1 means read entire dimension
setMethod("getVariable",
          signature(object="GdsGenotypeReader"),
          function(object, varname, snp, scan, ...) {

            if (!missing(snp) & !missing(scan)) {
              # get start and count from snp
              snpstart = snp[1]
              snpcount = snp[2]
            
              # get start and count from scan
              scanstart = scan[1]
              scancount = scan[2]

              callNextMethod(object, varname, start=c(snpstart, scanstart),
                             count=c(snpcount, scancount), ...)
            } else {
              callNextMethod(object, varname, ...)
            }
          })


# accessor methods
# index is logical or integer vector of indices to return
setMethod("getSnpID",
          signature(object="GdsGenotypeReader"),
          function(object, index) {
            var <- getVariable(object, object@snpIDvar)
            if (missing(index)) var else var[index]
          })

# char=TRUE to return character code
setMethod("getChromosome",
          signature(object="GdsGenotypeReader"),
          function(object, index, char=FALSE) {
            var <- getVariable(object, object@chromosomeVar)
            if (!missing(index)) var <- var[index]

            # convert to characters
            if (char) {
              # default is unknown code
              chromChar <- rep("U", length(var))
              autosome <- var %in% 1:22
              chromChar[autosome] <- as.character(var[autosome])
              xchrom <- var == object@XchromCode & !is.na(var)
              chromChar[xchrom] <- "X"
              ychrom <- var == object@YchromCode & !is.na(var)
              chromChar[ychrom] <- "Y"
              xychrom <- var == object@XYchromCode & !is.na(var)
              chromChar[xychrom] <- "XY"
              mchrom <- var == object@MchromCode & !is.na(var)
              chromChar[mchrom] <- "M"
              var <- chromChar
            }
            var
          })
                        
setMethod("getPosition",
          signature(object="GdsGenotypeReader"),
          function(object, index) {
            var <- getVariable(object, object@positionVar)
            if (missing(index)) var else var[index]
          })
                        
setMethod("getScanID",
          signature(object="GdsGenotypeReader"),
          function(object, index) {
            var <- getVariable(object, object@scanIDvar)
            if (missing(index)) var else var[index]
          })
 
setMethod("getGenotype",
          signature(object="GdsGenotypeReader"),
          function(object, ...) {
            var <- getVariable(object, object@genotypeVar, ...)
            # set missing values to NA
            var[!(var %in% c(0,1,2))] <- NA
            var
          })

setMethod("nsnp", "GdsGenotypeReader",
          function(object) {
            getDimension(object, object@snpIDvar)
          })

setMethod("nscan", "GdsGenotypeReader",
          function(object) {
            getDimension(object, object@scanIDvar)
          })

setMethod("XchromCode", "GdsGenotypeReader",
          function(object) {
            object@XchromCode
          })
          
setMethod("YchromCode", "GdsGenotypeReader",
          function(object) {
            object@YchromCode
          })
              
setMethod("XYchromCode", "GdsGenotypeReader",
          function(object) {
            object@XYchromCode
          })
              
setMethod("MchromCode", "GdsGenotypeReader",
          function(object) {
            object@MchromCode
          })
          