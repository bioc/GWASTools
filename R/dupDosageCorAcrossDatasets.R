## Function to calculate squared correlation (r2) between allelic dosages, both by scan and by SNP
## Allows for comparison between imputed datasets, or between imputed and observed -- i.e., where one or more of the datasets contains continuous dosage [0,2] rather than discrete allele counts {0,1,2}

## Modeled off of GWAS Tools function 'duplicateDiscordanceAcrossDatasets'

## Sarah Nelson, UW GAC, January 12, 2015
######################
## Development notes:

# uses getAlleleA and getAlleleB - user needs to name the desired snpAnnot allele columns to 'alleleA' and 'alleleB' prior to making the GenotypeData object (e.g., if the fields are initilaly named "alleleA.plus" and "alleleB.plus")

# only works for samples duplicated once (i.e. dup pairs not multiples)

# currently can handle reversed A/B alleles but not strand flips - could be extended in the future to handle strand flips, either via use of defineDupVars function directly or by incorporating ideas of defineDupVars into the internal .commonSnps function

# return a list - first element is data frame of correlation by variant,
# second element is data frame of correlation by sample

# TO ADD - warning message that strand flips at strand ambiguous SNPs will NOT be detected; recommend excluding strand ambiguous SNPs from the comparison
# alternatively, could try to do something smart like calcluate allele frequency and switch where counted allele is clearly different at A/T or C/G SNPs

######################
## Internal functions -- need to rename, other than 'My' prefix. Should have differnet names than GWASTools internal functions?


### II. Extract genotypes as count of A allele
# arguments: geno data object;
# list of desired scanIDs
# list of desired snpIDs
# returns geno matx in same snp x sample order as input lists
.dosCorSelectGenotype <- function(genoData, scanIDs, snpIDs) {
  scanSel <- getScanID(genoData) %in% scanIDs
  snpSel <- getSnpID(genoData) %in% snpIDs
  geno.init <- getGenotypeSelection(genoData, scan=scanSel, snp=snpSel)

  # discard Y chrom SNPs for females
  # NOTE - has NOT been tested on actualy chrY data (not imputed)
  if (hasSex(genoData)) {
    sex <- getSex(genoData, index=getScanID(genoData)[scanSel])
    females <- sex %in% "F"
    ychr <- getChromosome(genoData, char=TRUE) %in% "Y"
    if (sum(females) > 0 & sum(ychr) > 0) {
      geno.init[ychr, females] <- NA
    }
  }

  # sanity check: assign row and col names
  rownames(geno.init) <- getSnpID(genoData)[snpSel]
  colnames(geno.init) <- getScanID(genoData)[scanSel]

  # order to match input lists
  geno.init <- geno.init[as.character(snpIDs), as.character(scanIDs)]

  return(geno.init)
}

# dupDosageCorAcrossDatasets
# inputs:
# - list of GenotypeData objects
# - vector of common subject ID columns
# - vector of common snp ID columns
# - vectors of scans to exclude (optional)
# - vector of snp IDs to include (optional)
# - block size for by-snp calculation (defaults to 5000)
# - block size for by-samp calculation (defaults to 100)

dupDosageCorAcrossDatasets <- function(genoData1, genoData2,
                                       match.snps.on=c("position", "alleles"),
                                       subjName.cols="subjectID", snpName.cols=NULL,
                                       # one.pair.per.subj=TRUE,
                                       scan.exclude1=NULL, scan.exclude2=NULL,
                                       snp.exclude1=NULL, snp.exclude2=NULL,
                                       snp.include=NULL,
                                       snp.block.size=5000,
                                       scan.block.size=100,
                                       verbose=TRUE) {

  # perform initial checks as specified in duplicateDiscordanceAcrossdatasets
  subjName.cols <- .checkNameCols(subjName.cols)
  if (!is.null(snpName.cols)) snpName.cols <- .checkNameCols(snpName.cols)
  .initialChecks(genoData1, genoData2, match.snps.on, subjName.cols, snpName.cols)

  # find duplicate scans
  ids <- .duplicatePairs(genoData1, genoData2, subjName.cols,
                         scan.exclude1, scan.exclude2,
                         one.pair.per.subj=TRUE)
  if (is.null(ids)) {
    warning("no duplicate IDs found; check subjName.cols")
    return(NULL)
  }

  # unlist duplicate scan info into a data frame (assumes 1 pair per subject)
  samps <- data.frame(matrix(NA, nrow=length(ids), ncol=3))
  names(samps) <- c("subjectID","scanID1","scanID2")
  samps$subjectID <- names(ids)
  for (k in 1:(length(ids))){
    idk <- ids[[k]]
    samps$scanID1[k] <- idk$scanID[idk$dataset==1]
    samps$scanID2[k] <- idk$scanID[idk$dataset==2]
   }

  # find duplicate variants
  message("Matching variants on ",paste(match.snps.on,collapse=", "),"\n")
  snps <- .commonSnps(genoData1, genoData2, match.snps.on,
                      snpName.cols, snp.exclude1, snp.exclude2, snp.include)

  nsnps <- nrow(snps)
  nsamps <- nrow(samps)

  message("Calculating squared correlation of allelic dosages at ",
          prettyNum(nsnps, big.mark=",") ," overlapping variants in ",
          prettyNum(nsamps, big.mark=","), " duplicate sample pairs\n")

  # make a flag for where datasets are counting different allele
  # will conform second dataset to first by taking (2 - dosage) at these variants
  swapAB <- snps$alleleA1!=snps$alleleA2

  message("Detecting that the two datasets are counting different A alleles at ",
          prettyNum(sum(swapAB), big.mark=",")," variants\n")

  message("Getting genotypes:")

  #### using getGenotypeSelection
  scanIDs1 <- samps$scanID1
  snpIDs1 <- snps$snpID1
  geno1.matx <- .dosCorSelectGenotype(genoData=genoData1,
                                  scanIDs=scanIDs1,
                                  snpIDs=snpIDs1)

  scanIDs2 <- samps$scanID2
  snpIDs2 <- snps$snpID2
  geno2.matx <- .dosCorSelectGenotype(genoData=genoData2,
                                  scanIDs=scanIDs2,
                                  snpIDs=snpIDs2)

  # sanity checks on snp and sample alignment across matrices
  stopifnot(allequal(rownames(geno1.matx), snps$snpID1))
  stopifnot(allequal(rownames(geno2.matx), snps$snpID2))
  stopifnot(allequal(colnames(geno1.matx), samps$scanID1))
  stopifnot(allequal(colnames(geno2.matx), samps$scanID2))

  # adjust for potentially different allele A in second dataset
  geno2.matx[swapAB,] <- 2-geno2.matx[swapAB,]

  #### calculate r2 by snp
  message("\nCalculating r2 by SNP\n")

  # also keep track of how many samples went into calculation
  snps$dosageR2 <- snps$nsamp.dosageR2 <- NA

  last.row <- 0
  nblocks <- ceiling(nsnps / snp.block.size)
  for (i in 1:nblocks) {
    if(verbose){message("Block ",i," of ", nblocks)}
    idx <- (1:snp.block.size) + (i - 1) * snp.block.size
    # account for where there may be less snps in the block than the block size,
    # i.e., for final block
    if(i %in% max(nblocks)) {idx <- (last.row+1):nsnps}
    # print(idx)
    r.block <- diag(cor(t(geno1.matx[idx, ]),
                         t(geno2.matx[idx, ]),
                         use="pairwise.complete.obs"))
    r2.block <- r.block * r.block

    ## add how many samples went into calculation
    nonmiss.geno1 <- !is.na(geno1.matx[idx,])
    nonmiss.geno2 <- !is.na(geno2.matx[idx,])
    # now rowsums!
    ngeno1 <- rowSums(nonmiss.geno1)
    ngeno2 <- rowSums(nonmiss.geno2)
    # both geno1 and geno2 need to have non-missing data for
    # that sample to be used in calculating r2
    # resorting to apply
    dt <- matrix(data=c(ngeno1, ngeno2), nrow=length(idx), ncol=2)
    ncalc <- apply(dt,1,min)

    snps$dosageR2[idx] <- r2.block
    snps$nsamp.dosageR2[idx] <- ncalc
    last.row <- max(idx)
    # print(last.row)
  }

  #### calculate r2 by sample
  message("\nCalculating r2 by sample\n")
  last.row <- 0
   samps$dosageR2 <- samps$nsnp.dosageR2 <- NA
   nblocks <- ceiling(nsamps / scan.block.size)
   for (i in 1:nblocks) {
    if(verbose){message("Block ",i," of ", nblocks)}
    idx <- (1:scan.block.size) + (i - 1) * scan.block.size
    # account for where there may be less samples in the block than the block size,
    # i.e., for final block
    if(i %in% max(nblocks)) {idx <- (last.row+1):nsamps}
    # print(idx)
    r.block <- diag(cor(geno1.matx[,idx],
                        geno2.matx[,idx],
                        use="pairwise.complete.obs"))
    r2.block <- r.block * r.block

    ## add how many snps went into calculation
    nonmiss.geno1 <- !is.na(geno1.matx[,idx])
    nonmiss.geno2 <- !is.na(geno2.matx[,idx])
    # now colSums!
    ngeno1 <- colSums(nonmiss.geno1)
    ngeno2 <- colSums(nonmiss.geno2)
    # both geno1 and geno2 need to have non-missing data for
    # that snps to be used in calculating r2
    # resorting to apply
    dt <- matrix(data=c(ngeno1, ngeno2), nrow=length(idx), ncol=2)
    ncalc <- apply(dt,1,min)

    samps$dosageR2[idx] <- r2.block
    samps$nsnp.dosageR2[idx] <- ncalc
    last.row <- max(idx)
    #print(last.row)
  }

  message("\nFinished!\n")
  return(list(snps=snps, samps=samps))

} # end function definition