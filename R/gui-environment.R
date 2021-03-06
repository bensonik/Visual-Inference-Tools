new.vit.env <- function() {
	e <- new.env()

	e$pause <- FALSE

	# methods specifically for loading data
	e$fileReader <- function(){
		print("Importing file")

		e$specifyFileForImport()
	}

	e$odbcCloseAll <- function(){
		odbcCloseAll()
	}

	e$specifyFileForImport <- function(...) {
		e1 <- new.env()
		importFileWin <- gwindow("File Browser", cont = TRUE, parent = e$win)
		fileMainGp <- ggroup(cont = importFileWin, horizontal = FALSE)

		filetbl <- glayout(cont = fileMainGp)

		l <- list()
		l[[gettext("csv files")]] = c("csv")
		l[[gettext("2007 Excel files")]] = c("xlsx")
		l[[gettext("97-2003 Excel files")]] = c("xls")

		fileExtensions <- l
		pop <- function(x) x[-length(x)]
		popchar <- function(str) paste(pop(unlist(strsplit(str,""))),
			collapse="")

		filterList <- lapply(fileExtensions, function(i) list(patterns =
			paste("*.",i,sep="")))
		#filterList$"All files" = list(patterns=c("*"))

		ll = list()
		ll$"All files " <- list(patterns=c("*"))
		filterList <- c(ll,filterList)


		filetbl[2,2] <- glabel("Local file")
		filetbl[2,3] <- (filebrowse = gfilebrowse(text="Specify a file",
			action=invisible, container=filetbl, filter=filterList,
			quote=FALSE))
		filetbl[3,2:3] <- gseparator(cont=filetbl)
		filetbl[4,2] = gettext("File type is")
		filetbl[4,3] <- (filetype = gdroplist(c(
			"<use file extension to determine>", sapply(names(
			filterList[!filterList %in% ll]),popchar)), cont=filetbl))
		visible(filetbl) <- TRUE

		buttonGp <- ggroup(cont = fileMainGp)
		addSpring(buttonGp)
		okButton <- gbutton("OK",
			handler = function(h,...) e1$okButtonHandler())
		cancelButton <- gbutton("Cancel",
			handler = function(h,...) e1$cancelButtonHandler())
		add(buttonGp, okButton)
		add(buttonGp, cancelButton)

		add(fileMainGp, glabel(
			"Space for extra options: define NA string, header presence etc."))

		e1$cancelButtonHandler <- function(h,...) dispose(importFileWin)

		e1$okButtonHandler <- function(h,...) {
			theFile <- svalue(filebrowse)
			ext <- NULL ## the extension, figure out

			if(theFile == "Specify a file" || !file.exists(theFile)) {
				# missing code? - Garrett
			}else{
				fileType <- svalue(filetype)
				if(fileType != "<use file extension to determine>") {
    	  			## use filterList to get
					fileType <- paste(fileType,"s", sep="", collapse="")
					## append s back
					ext <- fileExtensions[[fileType]][1]
				sprintf("Set extension to %s \n",ext)
				} else if(is.null(ext)) {
					tmp <- unlist(strsplit(basename(theFile), split="\\."))
					ext <- tmp[length(tmp)]
				}
			e1$importFile(theFile, ext)
			}
		}

		e1$importFile <- function(theFile, ext){
			tmp <- unlist(strsplit(basename(theFile), split="\\."))
			ext.tmp <- tmp[length(tmp)]

			if(length(ext) == 0) {
				gmessage(title = "Error", message = "Check file type",
					icon = "error", cont = TRUE, parent = importFileWin)
			} else if(ext.tmp != ext) {
				gmessage(title = "Error", message =
					"Chosen file is different than the selected file type",
			   		icon = "error", cont = TRUE, parent = importFileWin)
			} else if(ext == "csv") {
				out <- try(read.csv(theFile, header = TRUE,
					na.strings = c("NULL","NA","N/A","#N/A","","<NA>"),
					check.names = TRUE))
				if(inherits(out,"try-error")){
					sprintf("Error loading file: %s\n",out)
					enabled(okButton) = TRUE
					return(TRUE)
				}else{
					enabled(okButton) <- FALSE
					out <- data.frame(ROW_NAME = 1:nrow(out), out,
						check.names = TRUE)
					tag(e$obj,"dataSet") <- out[,-1]
					tag(e$obj,"rowDataSet") <- out
					tag(e$obj, "originalDataSet") <- tag(e$obj,"dataSet")
					e$inDataView <- TRUE
					enabled(e$dataView) <- FALSE
					enabled(e$listView) <- TRUE
					e$updateData()
					enabled(okButton) <- TRUE
					e$clearAllSlots()
					dispose(importFileWin)
				}
	      }else if(ext == "xls" || ext == "xlsx"){
				channel <- try(odbcConnectExcel2007(theFile, readOnly = TRUE,
					readOnlyOptimize=TRUE))
				if(inherits(channel,"try-error")) {
					sprintf("Error loading file: %s\n",channel)
					enabled(okButton) <- TRUE
					e$odbcCloseAll()
					return(TRUE)
				}else{
					enabled(okButton) <- FALSE
					#no na.omit()
					out <- try(sqlFetch(channel, sqtable = "Sheet1",
					na.strings = c("NULL","NA","N/A","#N/A","","<NA>"),
						as.is = TRUE))
					if(inherits(out,"try-error")){
						gmessage("Please ensure that the Excel worksheet containing the data is named as Sheet1\n\nIf the error persists, please save the dataset as a CSV (comma separated) file", parent = importFileWin)
						enabled(okButton) <- TRUE
					}else{
						out <- data.frame(ROW_NAME = 1:nrow(out), out)
						names(out) <- make.names(names(out), unique=TRUE)

						for(i in 1:length(names(out))){
							x <- as.numeric(out[,i])
							if(all(is.na(x)))
								out[,i] <- factor(as.character(out[,i]))
							else out[,i] <- x
						}
						tag(e$obj,"dataSet") <-  out[,-1]
						tag(e$obj,"rowDataSet") <- out
						tag(e$obj, "originalDataSet") <- tag(e$obj,"dataSet")
						e$inDataView <- TRUE
						enabled(e$dataView) <- FALSE
						enabled(e$listView) <- TRUE
						e$updateData()
						enabled(okButton) <- TRUE
						e$clearAllSlots()
						dispose(importFileWin)
						e$odbcCloseAll()
					}
				}
			}
		}
	}

	e$updateData <- function() {
		names(tag(e$obj,"dataSet")) <- make.names(names(tag(e$obj,"dataSet")),
			unique = TRUE)
		tag(e$obj,"rowDataSet") <- data.frame( ROW_NAME = tag(e$obj,
			"rowDataSet")[,1], tag(e$obj, "dataSet"))
		names(tag(e$obj,"rowDataSet")) <- make.names(names(tag(e$obj,
			"rowDataSet")), unique = TRUE)

		if(!is.null(e$dataList))
			delete(e$dataGp, e$dataList, expand = TRUE)
		if(!is.null(e$dataList1))
			delete(e$dataGp, e$dataList1, expand = TRUE)
		if(!is.null(e$dataList2))
			delete(e$dataGp, e$dataList2, expand = TRUE)
		if(!is.null(e$dataSt))
			delete(e$dataGp, e$dataSt, expand = TRUE)

		e$dataSt <- gdf(tag(e$obj,"dataSet"),expand = TRUE)
		add(e$dataGp, e$dataSt, expand = TRUE)
		addHandlerChanged(e$dataSt,
			handler = function(h,...) tag(e$obj,"dataSet") = e$dataSt[])
	    e$inDataView = TRUE
	}

	e$updateList <- function() {
		names(tag(e$obj,"dataSet")) <- make.names(names(tag(e$obj,"dataSet")),
			unique = TRUE)
		tag(e$obj,"rowDataSet") <- data.frame(ROW_NAME = tag(e$obj,
			"rowDataSet")[,1], tag(e$obj, "dataSet"))
		names(tag(e$obj,"rowDataSet")) <- make.names(names(tag(e$obj,
			"rowDataSet")), unique = TRUE)

		if(!is.null(e$dataList))
			delete(e$dataGp, e$dataList, expand = TRUE)
		if(!is.null(e$dataList1))
			delete(e$dataGp, e$dataList1, expand = TRUE)
		if(!is.null(e$dataList2))
			delete(e$dataGp, e$dataList2, expand = TRUE)
		if(!is.null(e$dataSt))
			delete(e$dataGp, e$dataSt, expand = TRUE)

		N = 19
		# if(e$sliderCreated && e$sliderCreated2) N = 14

		if((length(names(tag(e$obj,"dataSet"))) > N) &&
			(length(names(tag(e$obj,"dataSet"))) < 80)){
				x <- length(names(tag(e$obj,
					"dataSet"))[(N+1):(length(names(tag(e$obj,"dataSet"))))])
				d1 <- (names(tag(e$obj,"dataSet"))[1:N])
				d2 <- c(names(tag(e$obj,
					"dataSet"))[(N+1):(length(names(tag(e$obj,"dataSet"))))])
				e$dataList1 <- gtable(d1,expand = TRUE)
				names(e$dataList1) <- "VARIABLES"
				e$dataList2 <- gtable(d2,expand = TRUE)
				names(e$dataList2) <- "...CONTINUED"
				adddropsource(e$dataList1)
				adddropsource(e$dataList2)
				add(e$dataGp, e$dataList1, expand = TRUE)
				add(e$dataGp, e$dataList2, expand = TRUE)
		} else {
			d <- names(tag(e$obj,"dataSet"))
			e$dataList <- gtable(d,expand = TRUE)
			names(e$dataList) <- "VARIABLES"
			adddropsource(e$dataList)
			add(e$dataGp, e$dataList, expand = TRUE)
		}

		e$inDataView <- FALSE
	}

        e$viewData <- function(h, ...){
            if(is.null(tag(e$obj, "dataSet"))) {
                gmessage("Please load a new data set (with named columns)",
                         parent = e$win)
            } else if ((names(tag(e$obj, "dataSet"))[1] == "empty")) {
                gmessage("Please load a new data set", parent = e$win)
            } else {
                enabled(h$obj) = FALSE
                e$updateData()
                enabled(e$listView) = TRUE
                e$inDataView = TRUE
            }
	}

	e$viewList <- function(h, ...){
		if(is.null(tag(e$obj, "dataSet"))) {
			gmessage("Please load a new data set (with named columns)",
				parent = e$win)
		} else if(names(tag(e$obj, "dataSet"))[1] == "empty") {
				gmessage("Please load a new data set", parent = e$win)
		} else {
			enabled(h$obj) <- FALSE
			e$updateList()
			enabled(e$dataView) <- TRUE
			e$inDataView <- FALSE
      }
    }


	# Handlers and widget construction

	# buildCanvas creates a canvas object from the R5 reference class canvas. This canvas object is saved in the GUI environment and handles all of the graphical displays in the vit tool. It may help to keep GUI methods (functions that begin with e$ ) separate in your mind from the canvas methods (functions that begin with e$c1$	). They behave a little differently. In general GUI methods affect the gui environment and canvas methods affect the canvas object. Handler functions that work with both are saved to the top level whenever possible. Indexes and samples can be given so that a new canvas object cointains the same samples as the previous one.
	e$buildCanvas <- function(){
            e$c1 <- canvas$new(x = e$xData, levels = e$yData)
            ## loads the data dependent details that allow the canvas to perform
            ## its basic actions. NOTE: should actions be stored in e?
            buildViewports(e$c1, e$xData, e$yData, e$data.boxes, e$same.stat.scale)
            e$c1$buildImage(e$data.boxes)
            pushViewport(e$c1$viewports)
            e$c1$plotData()
	}

	e$clearAllSlots <- function(){
		svalue(e$xVar) <- "Drop name here"
		e$e$xData <- NULL
		tag(e$obj,"e$xVarData") <- NULL
		svalue(e$yVar) <- "Drop name here"
		e$e$yData <- NULL
	}

	e$reverseVariables <- function() {
		temp <- e$xData
		e$xData <- e$yData
		e$yData <- temp

		temp <- svalue(e$xVar)
		svalue(e$xVar) <- svalue(e$yVar)
		svalue(e$yVar) <- temp
	}

	# Arranges all the details for calculating statistics by making samples and
	# picking a correct sampling method.
	e$sample_check <- function() {
		# check for potential trouble
		if (!is.null(e$xData)){
			if (e$replace == FALSE & as.numeric(svalue(e$ssize)) >
				length(e$xData)) {
					grid.newpage()
					grid.text("Sample size can not exceed data size when sampling without replacement.")
					svalue(e$ssize) <- length(e$xData)
					return()
			}

			if (as.numeric(svalue(e$ssize)) < 2) {
				grid.newpage()
                grid.text("Sample size must be > 1.")
                svalue(e$ssize) <- 2
                return()
			}
		}
	}

	e$variable_check <- function() {
            e$data.loaded <- FALSE
            if (is.null(e$xData)) {
                grid.newpage()
                grid.text("Please select Variable 1")
                return()
            }

            if (is.categorical(e$xData) & !is.categorical(e$yData) &
                !is.null(e$yData)) {
                e$reverseVariables()
		}

            if (is.categorical(e$xData) & is.categorical(e$yData)) {
                grid.newpage()
                grid.text("Methods do not yet exist for this type of data.")
                print("Methods have not yet been implemented for 2D categorical data.")
                return()
            }

            if (!is.categorical(e$xData) & !is.categorical(e$yData) &
                !is.null(e$yData)) {
                grid.newpage()
                grid.text("Methods do not yet exist for this type of data.")
                print("Methods have not yet been implemented for 2D numerical data.")
                return()
            }

            if (is.categorical(e$xData) & is.null(e$yData)) {
                grid.newpage()
                grid.text("Methods do not yet exist for this type of data.")
                print("Methods have not yet been implemented for 1D categorical data.")
                return()
            }
            e$data.loaded <- TRUE
	}

        e$na_check <- function(for.x = TRUE){
            if (for.x){
                e$xNA <- e$xData
                if (is.null(e$yData)){
                    e$xData <- e$xNA[!is.na(e$xNA)]
                } else {
                    subset <- is.na(e$xNA) | is.na(e$yNA)
                    e$xData <- e$xNA[!subset]
                    e$yData <- e$yNA[!subset]
                }
            } else {
                e$yNA <- e$yData
                if (is.null(e$xData)){
                    e$yData <- e$yNA[!is.na(e$xNA)]
                } else {
                    subset <- is.na(e$xNA) | is.na(e$yNA)
                    e$xData <- e$xNA[!subset]
                    e$yData <- e$yNA[!subset]
                }
            }
        }


        ## Clears bottom two panels of canvas.
        e$resetCanvas <- function() {
            clear_actions(e)
            e$buildCanvas()
            if (e$data.boxes) e$c1$buildBoxes()
            e$c1$drawImage()
        }

        ## Clears bottom two panels of canvas but holds onto current sample.
        e$resetCanvasKeepSample <- function(old.canvas){
            old.samples <- old.canvas$samples
            old.indexes <- old.canvas$indexes
            e$resetCanvas()
            e$c1$samples <- old.samples
            e$c1$indexes <- old.indexes
            e$c1$which.sample <- 1
        }

        ## Clears bottom panel of canvas
        e$clearPanel <- function(panel = "stat"){
            clear.panel <- paste(panel, "Plot", sep = "")
            grobs <- childNames(e$c1$image)
            grobs.to.clear <- grobs[substr(grobs, 1, nchar(panel) + 4) == clear.panel]
            for (i in grobs.to.clear)
                e$c1$image <- removeGrob(e$c1$image, i)
        }

        e$graphPath <- function(plot.name = "sample", number = "1", boxes = e$data.boxes)
            graphPath(plot.name = plot.name, number = number, boxes = boxes)

        e
}
