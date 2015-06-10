library(stringr)
library(lsr)

sum_walltime <- function(kind,nodes)
{

    main_dir <- "Distem_expe_cores"
    max <- 512
    
    files <- c()
    for(num in nodes){
        if(num>max) break
        files <- c(files,system(paste("ls ",main_dir,"/profile_global_*",kind,"_",bench,"_",num,".txt",sep=""), intern =TRUE))
    }

    def <- data.frame()
    for(file in files){
        
        print(paste("Reading file: ",file))
        ## read the file as a data frame
        data = read.table(file)
        r <- "profile_global_\\w+_.*_(\\d+).txt"
  
        temp_match <- str_match_all(file,r)
        processes <- as.numeric(temp_match[[1]][,2])

        print(processes)
        ## It assgins meaningful names for each column 
        colnames(data) <-c('percent','exclu','inclu','num_calls','subrs','usec','name')

        ## it select the column of interesent, feel free to change it and select other columns
        relevant <- subset(data, select = c('name','usec','percent'))
                                        # It eliminates rare methods
                                        # It aggregates all values using 'mean'
        summary_table <- aggregate(relevant[,2:3], list(relevant$name), mean)

        # generating the confidence interval
        ci <- aggregate(relevant[,2:3], list(relevant$name), ciMean)
        summary_table$ci1 <- ci$usec[,1]
        summary_table$ci2 <- ci$usec[,2]
        
                                        # It assgins meaningful names for each column 
        colnames(summary_table) <-c('method','usec','percent','ci1','ci2')

        appli <- subset(summary_table, as.numeric(percent) > 99)

        if(kind == "container16"){
            kind = "container"
        }
        
        if(kind == "native16"){
            kind = "native"
        }
        
        def <- rbind(def,data.frame(walltime = appli$usec, numprocess = processes,  type = kind, ci1=appli$ci1,ci2=appli$ci2))

    }
    return(def)
}





