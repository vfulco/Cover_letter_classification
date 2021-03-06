# Cover letter text classification

#get correct working directory from user containing cover letters:
# wd <- readline(prompt="Please enter the path to the directory containing cover letters: ")
# temp <- try(setwd(wd), silent = T)
# while(class(temp)=='try-error'){
#   wd <- readline(prompt="This path does not exist. Please enter directory containing cover letters: ")
#   temp <- try(setwd(wd), silent = T)
# }
setwd('/Users/fineiskid/Desktop/Internships:Jobs/All_cover_letters/')
library(qdap)

#store filenames and target vector. Get priors.
D = list.files()
N = length(D)

class_file <- function(file){
  '
  ARGS:
  file (char): filename of .docx cover letter file
  '
  splt <- strsplit(file, split = "")[[1]]
  if("0" %in% splt){
    return(0)
  }
  else{
    return(1)
  }
}

#store file names and class in matrix:
name_class_stor <- matrix(NA, ncol = 2, nrow = N)
name_class_stor[,1] <- D
name_class_stor[,2] <- sapply(D, FUN=class_file)

#function to read .docx file
read_file <- function(file){
  '
  ARGS:
  file (char): filename of .docx cover letter file
  '
  skip = 1; r = F
  while (!r){
    paste('Attempting to read file', file, sep = ' ')
    f = try(read.transcript(file, skip = skip, apostrophe.remove = T), silent = T)
    if (class(f) == "try-error"){
      skip = skip + 1
    }
    if(class(f) != "try-error"){
      r = T
    }
    if(skip > 200){
      print(paste("File", file, "could not be read\n"), sep = " ")
      return(NULL)
    }
  }
  return(f)
}

#clean text when it's given as a giant sentence, like from read.transcript
text_cleaner <- function(text){
  '
  ARGS (char): string, unsplit.
  '
  text = strsplit(as.character(text), split = " ")
  text = unlist(lapply(text, strsplit, split = "/"))
  text <- text[!grepl("[[:digit:]]", text)]
  text <- text[!is.null(text)]
  for (t in 1:length(text)){
    text[t] <- tolower(text[t])
    text[t] <- gsub("[[:punct:]]", "", text[t])
    if(!is.null(text[t])){
      indv_letters <- strsplit(text[t], '')[[1]]
      for (letter in indv_letters){
        if (!letter %in% letters){
          indv_letters = indv_letters[indv_letters!=letter]
        }
      }
      text[t] <- paste(indv_letters, collapse = '')
    }
  }
  return(text)
}



#get dictionary of all words for certain class
text_for_class <- function(class = 0, ncs=name_class_stor){
  '
  ARGS:
  class (int): indicates success (1) or failure (0) of hearing back given a cover letter
  name_class_stor (matrix): 2-column matrix with filenames (one column) and document class (second column)
  '
  class_text = vector(mode = 'character'); ctr = 1
  files <- ncs[which(ncs[,2]==class),]
  for (ii in 1:nrow(files)){
    print(paste("Attempting to read file", files[ii,1], sep = " "))
    f = read_file(files[ii,1])
    if (is.null(f)){
      ncs <- ncs[which(ncs[,1]!=files[ii,1]),]}
    if (!is.null(f)){
      dims = dim(f)
      for (k in 1:dims[1]){
        for (j in 1:dims[2]){
          #turn this into a function to clean text
          text = text_cleaner(f[k,j])
          class_text= c(class_text, text)
        }
      }
    }
  }
  ncs <- ncs[which(ncs[,2]==class),]
  return(list(text = class_text[class_text!=""], name_class_stor = ncs))
}

#list of all words used, per class, with repetitions allowed
c0 <- text_for_class(class = 0, name_class_stor)
c0_tokens <- c0$text
c1 <- text_for_class(class = 1, name_class_stor)
c1_tokens <- c1$text
name_class_stor <- rbind(c0$name_class_stor, c1$name_class_stor)
V <- unique(c(c0_tokens, c1_tokens))

#count token occurences, according to class:
reduce <- function(class_tokens, V_vec=V){
  '
  ARGS:
  class_tokens (char vector): the non-unique vector of word occurences pertaining to a certain class
  V (char vector): entire vocabulary
  '
  keys <- V_vec
  vals <- NULL
  for (k in 1:length(V_vec)){
    vals <- c(vals, sum(class_tokens==keys[k]))}
  return(as.data.frame(cbind(keys, as.numeric(vals))))
}

#store matrix of conditional probabilities:
condprob = as.data.frame(matrix(nrow = length(V), ncol = 2))
colnames(condprob) <- c('Class0', 'Class1')
rownames(condprob) <- V
counts_0 <- reduce(c0_tokens, V=V); S0 <- length(c0_tokens)
counts_1 <- reduce(c1_tokens, V=V); S1 <- length(c1_tokens)
condprob[,1] <- (as.numeric(counts_0[,2]) + 1)/(S0 + length(V))
condprob[,2] <- (as.numeric(counts_1[,2]) + 1)/(S1 + length(V))

#get class priors
p1 <- sum(as.numeric(name_class_stor[,2]))/nrow(name_class_stor)
p0 <- sum(as.numeric(name_class_stor[,2]==0))/nrow(name_class_stor)
priors <- c(p0,p1)

test_doc_classify <- function(file, V_vec=V, cp = condprob, p = priors){
  '
  ARGS:
  file (char): filename of test document we wish to classify
  V (char vector): vector of all previously seen vocabulary
  condprob (numeric 2-d array): class conditional probabilities of each word
  priors (numeric vector): class priors
  '
  f <- read_file(file)
  t <- NULL
  if (!is.null(f)){
    dims = dim(f)
    for (k in 1:dims[1]){
      for (j in 1:dims[2]){
        #turn this into a function to clean text
        text = text_cleaner(f[k,j])
        t <- c(t, text)
      }
    }
    t <- unique(t[which(t %in% V_vec)])
    scores <- NULL
    for (c in 0:1){
      loglik <- 0
      log_prior <- log(p[c+1])
      loglik <- loglik + log_prior
      for (word in 1:length(t)){
        loglik <- loglik + log(cp[which(rownames(cp)==t[word]),c+1])
      }
      scores <- c(scores, loglik)
    }
    scores <- as.data.frame(t(scores))
    colnames(scores) <- c('0', '1')
    cl <- as.numeric(names(which.max(scores)))
    cat("Most likely class of new file: ", cl, '\n')
    return(cl)
  }
  else{
    print('Something went wrong while reading this file!\n')
    return(NULL)
  }
}

#Obtain overall success/misclassification rate:
success_vec <- matrix(0, nrow = nrow(name_class_stor), ncol = 1)
for (i in 1:nrow(name_class_stor)){
  ncs_temp <- name_class_stor[which(name_class_stor[,1]!=name_class_stor[i,1]),]
  c0 <- text_for_class(class = 0, ncs_temp)
  c0_tokens <- c0$text
  c1 <- text_for_class(class = 1, ncs_temp)
  c1_tokens <- c1$text
  ncs_temp <- rbind(c0$name_class_stor, c1$name_class_stor)
  V <- unique(c(c0_tokens, c1_tokens))
  p1 <- sum(as.numeric(ncs_temp[,2]))/nrow(ncs_temp)
  p0 <- sum(as.numeric(ncs_temp[,2]==0))/nrow(ncs_temp)
  priors <- c(p0,p1)
  condprob = as.data.frame(matrix(nrow = length(V), ncol = 2))
  colnames(condprob) <- c('Class0', 'Class1')
  rownames(condprob) <- V
  counts_0 <- reduce(c0_tokens, V_vec=V); S0 <- length(c0_tokens)
  counts_1 <- reduce(c1_tokens, V_vec=V); S1 <- length(c1_tokens)
  condprob[,1] <- (as.numeric(counts_0[,2]) + 1)/(S0 + length(V))
  condprob[,2] <- (as.numeric(counts_1[,2]) + 1)/(S1 + length(V))
  pred <- test_doc_classify(file = name_class_stor[i,1])
  if (pred == name_class_stor[i,2]){
    success_vec[i] <- 1
  }
}

error_rate <- sum(success_vec==0)/nrow(name_class_stor)
predictions <- as.data.frame(cbind(name_class_stor[,1], success_vec))
colnames(predictions) <- c('File name', 'Predicted Class')
cat('Overall misclassification rate: ', error_rate, '\n')



