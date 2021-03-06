####################################################################
#' Frequencies Calculations and Plot
#' 
#' This function lets the user group, count, calculate percentages 
#' and cumulatives. It also plots results if needed. Tidyverse friendly.
#' 
#' @family Exploratory
#' @family Visualization
#' @param df Data.frame
#' @param ... Variables. Variables you wish to process. Order matters.
#' If no variables are passed, the whole data.frame will be considered
#' @param wt Variable, numeric. Weights.
#' @param rel Boolean. Relative percentages (or absolute)?
#' @param results Boolean. Return results in a dataframe?
#' @param variable_name Character. Overwrite the main variable's name
#' @param plot Boolean. Do you want to see a plot? Three variables tops.
#' @param rm.na Boolean. Remove NA values in the plot? (not filtered for 
#' numerical output; use na.omit() or filter() if needed)
#' @param title Character. Overwrite plot's title with.
#' @param subtitle Character. Overwrite plot's subtitle with.
#' @param top Integer. Filter and plot the most n frequent for 
#' categorical values. Set to NA to return all values
#' @param abc Boolean. Do you wish to sort by alphabetical order?
#' @param save Boolean. Save the output plot in our working directory
#' @param subdir Character. Into which subdirectory do you wish to 
#' save the plot to?
#' @export
freqs <- function(df, ..., wt = NULL,
                  rel = FALSE,
                  results = TRUE, 
                  variable_name = NA, 
                  plot = FALSE, rm.na = FALSE,
                  title = NA, subtitle = NA,
                  top = 20, abc = FALSE,
                  save = FALSE, subdir = NA) {
  
  vars <- quos(...)
  weight <- enquo(wt)
  
  # Probably an error but might be usefull for the user instead
  if (length(vars) == 0) {
    output <- freqs_df(df, plot = !plot, save = save, subdir = subdir)
    return(output)
  }
  
  output <- df %>% 
    group_by(!!!vars) %>% tally(wt = !!weight) %>% 
    arrange(desc(n)) %>%
    {if (!rel) ungroup(.) else .} %>%
    mutate(p = round(100*n/sum(n), 2), pcum = cumsum(p))  
  
  # Sort values alphabetically or ascending if numeric
  if (abc) {
    message("Sorting variable(s) alphabetically")
    output <- output %>% arrange(!!!vars, desc(n)) %>% 
      mutate(order = row_number())
  } else {
    output <- output %>% arrange(desc(n)) %>%
      mutate(order = row_number())
  }
  
  # No plot
  if (!plot && !save)
    if (results) return(output) else invisible(return())
  
  if (ncol(output) - 3 >= 4) {
    stop(
      paste("Sorry, but trying to plot more than 3 features is as complex as it sounds.",
            "You should try another method to understand your analysis!"))
  }
  obs_total <- sum(output$n)
  obs <- paste("Total Obs.:", formatNum(obs_total, 0))
  weight_text <- ifelse((as_label(weight) != "NULL"), 
                        paste0("(weighted by ", as_label(weight), ")"), "")
  
  # Use only the most n frequent values/combinations only
  values <- unique(output[,(ncol(output) - 3)])
  if (nrow(values) > top) {
    if (!is.na(top)) {
      output <- output %>% slice(1:top)
      message(paste0("Slicing the top ", top, 
                     " (out of ", nrow(values),
                     ") frequencies; use 'top' parameter to overrule."))
      note <- paste0("[", top, " most frequent]")
      obs <- paste0("Obs.: ", formatNum(sum(output$n), 0), " (out of ", formatNum(obs_total, 0), ")")
    }
  } else {note <- ""}
  
  if (abc) note <- gsub("most frequent", "A-Z sorted values", note)
  
  reorder_within <- function(x, by, within, fun = mean, sep = "___", ...) {
    new_x <- paste(x, within, sep = sep)
    stats::reorder(new_x, by, FUN = fun)
  }
  scale_x_reordered <- function(..., sep = "___") {
    reg <- paste0(sep, ".+$")
    ggplot2::scale_x_discrete(labels = function(x) gsub(reg, "", x), ...)
  }
  
  plot <- ungroup(output)
  
  if (rm.na)  plot <- plot[complete.cases(plot), ]
  
  # Create some dynamic aesthetics
  plot$labels <- paste0(formatNum(plot$n, decimals = 0),
                        " (", signif(plot$p, 4), "%)")
  plot$label_colours <- ifelse(plot$p > mean(range(plot$p)) * 0.9, "m", "f")
  lim <- 0.35
  plot$label_hjust <- ifelse(
    plot$n < min(plot$n) + diff(range(plot$n)) * lim, -0.1, 1.05)
  plot$label_colours <- ifelse(
    plot$label_colours == "m" & plot$label_hjust < lim, "f", plot$label_colours)
  variable <- colnames(plot)[1]
  
  # When one feature
  if (ncol(output) - 3 == 2) { 
    type <- 1
    colnames(plot)[1] <- "names"
    p <- ggplot(plot) + aes(x = reorder(names, -order), y = n, label = labels, fill = p)
  }
  # When two features
  else if (ncol(output) - 3 == 3) { 
    type <- 2
    facet_name <- colnames(plot)[2]
    colnames(plot)[1] <- "facet"
    colnames(plot)[2] <- "names"
    plot$facet[is.na(plot$facet)] <- "NA"
    p <- plot %>%
      ggplot(aes(x = reorder_within(names, -order, facet), 
                 y = n, label = labels, fill = p)) +
      scale_x_reordered()
  }
  # When three features
  else if (ncol(output) - 3 == 4) { 
    type <- 3
    facet_name1 <- colnames(plot)[2]
    facet_name2 <- colnames(plot)[3]
    colnames(plot)[1] <- "facet2"
    colnames(plot)[2] <- "facet1"
    colnames(plot)[3] <- "names"
    plot$facet2[is.na(plot$facet2)] <- "NA"
    plot$facet1[is.na(plot$facet1)] <- "NA"
    p <- plot %>%
      ggplot(aes(x = reorder_within(names, n, facet2), 
                 y = n, label = labels, fill = p)) +
      scale_x_reordered()
  }
  
  # Plot base
  p <- p + geom_col(alpha = 0.95, width = 0.8, colour = "transparent") +
    geom_text(aes(hjust = label_hjust, colour = label_colours), size = 2.8) + 
    coord_flip() + guides(colour = FALSE) +
    labs(x = NULL, y = NULL, fill = NULL,
         title = ifelse(is.na(title), paste("Frequencies and Percentages"), title),
         subtitle = ifelse(is.na(subtitle), 
                           paste("Variable:", ifelse(!is.na(variable_name), variable_name, variable), note, weight_text), 
                           subtitle), caption = obs) +
    scale_fill_gradient(low = "lightskyblue2", high = "navy") +
    theme_lares2(legend = "none", grid = "Xx") + gg_text_customs() + 
    scale_y_continuous(position = "right", expand = c(0, 0), labels = comma,
                       limits = c(0, 1.03 * max(output$n)))
  
  # When two features
  if (type == 2) { 
    p <- p + 
      facet_grid(as.character(facet) ~ ., scales = "free", space = "free") + 
      labs(subtitle = ifelse(is.na(subtitle), 
                             paste("Variables:", facet_name, "grouped by", variable, "\n", note, weight_text), 
                             subtitle),
           caption = obs)
  }
  
  # When three or more features
  else if (type >= 3) { 
    if (length(unique(facet_name2)) > 3) {
      p <- freqs_plot(df, ..., top = top, rm.na = rm.na, title = title, subtitle = subtitle)
      return(p)
    }
    p <- p + facet_grid(as.character(facet2) ~ as.character(facet1), scales = "free") + 
      labs(title = ifelse(is.na(title), "Frequencies and Percentages:", title),
           subtitle = ifelse(is.na(subtitle), 
                             paste("Variables:", facet_name2, "grouped by", facet_name1, "[x] and", 
                                   variable, "[y]", "\n", note, weight_text), 
                             subtitle),
           caption = obs)
  }
  
  # Export file name and folder for plot
  if (save) export_plot(p, "viz_freqs", vars, subdir = subdir)
  return(p)  
}


####################################################################
#' All Frequencies on Data Frame
#' 
#' This function lets the user analize data by visualizing the
#' frequency of each value of each column from a whole data frame.
#' 
#' @family Exploratory
#' @family Visualization
#' @param df Data.frame
#' @param max Numeric. Top variance threshold. Range: (0-1].
#' These variables will be excluded
#' @param min Numeric. Minimum variance threshold. Range: [0-1). 
#' These values will be grouped into a high frequency (HF) value
#' @param novar Boolean. Remove no variance columns?
#' @param plot Boolean. Do you want to see a plot? Three variables tops
#' @param top Integer. Plot most relevant (less categories) variables
#' @param quiet Boolean. Keep quiet? (or show variables exclusions)
#' @param save Boolean. Save the output plot in our working directory
#' @param subdir Character. Into which subdirectory do you wish to 
#' save the plot to?
#' @export
freqs_df <- function(df, 
                     max = 0.9, min = 0.0, novar = TRUE,
                     plot = TRUE, top = 30,
                     quiet = FALSE,
                     save = FALSE, subdir = NA) {
  
  if (is.vector(df)) stop("df should be a data frame, not a vector")
  df <- df[!unlist(lapply(df, is.list))]
  names <- lapply(df, function(x) length(unique(x)))
  unique <- as.data.frame(names)
  colnames(unique) <- names(names)
  which <- rownames(t(-sort(unique)))
  
  # Too much variance
  no <- names(unique)[unique > nrow(df) * max]
  if (length(no) > 0) {
    if (!quiet) message(paste(length(no), "variables with more than", max, 
                              "variance exluded:", vector2text(no)))
    which <- which[!which %in% no] 
  }
  
  # No variance at all
  if (novar) {
    no <- zerovar(df)
    if (length(no) > 0) {
      if (!quiet) message(paste(length(no), "variables with no variance exluded:", 
                                vector2text(no)))
      which <- which[!which %in% no] 
    } 
  }
  
  # Too many columns
  if (length(which) > top) {
    no <- which[(top + 1):length(which)]
    if (!quiet) message(paste("Using the", top, "variables with less distinct categories.",
                              length(no), "variables excluded:", vector2text(no)))
    which <- which[1:top]
  }
  
  if (length(which) > 0) {
    for (i in 1:length(which)) {
      if (i == 1) out <- c()
      iter <- which[i]
      counter <- table(df[iter], useNA = "ifany")
      res <- data.frame(value = names(counter), count = as.vector(counter), col = iter) %>%
        arrange(desc(count))
      out <- rbind(out, res)
    } 
    out <- out %>% 
      mutate(p = round(100 * count / nrow(df), 2)) %>%
      mutate(value = ifelse(p > min * 100, as.character(value), "(HF)")) %>%
      group_by(col, value) %>% summarise(p = sum(p), count = sum(count)) %>% 
      arrange(desc(count)) %>% ungroup()
  } else { 
    warning("No relevant information to display regarding your data.frame!") 
    return(invisible(NULL))
  }
  
  if (plot) {
    out <-  out %>%
      mutate(value = ifelse(is.na(value), "NA", as.character(value))) %>%
      mutate(col = factor(col, levels = which)) %>%
      mutate(label = ifelse(p > 8, as.character(value), "")) %>%
      group_by(col) %>% mutate(alpha = log(count)) %>%
      mutate(alpha = as.numeric(ifelse(value == "NA", 0, alpha))) %>%
      mutate(alpha = as.numeric(ifelse(is.infinite(alpha), 0, alpha)))
    
    p <- ggplot(out, aes(x = col, y = count, fill = col, label = label, colour = col)) + 
      geom_col(aes(alpha = alpha), position = "fill", 
               colour = "transparent", width = 0.95, size = 0.1) + 
      geom_text(position = position_fill(vjust = .5), size = 3) +
      coord_flip() + labs(x = NULL, y = NULL, title = "Global Values Frequencies") +
      scale_y_percent(expand = c(0, 0)) +
      guides(fill = FALSE, colour = FALSE, alpha = FALSE) +
      theme_lares2(pal = 1) + 
      theme(panel.background = element_blank(),
            panel.grid.major = element_blank(), 
            panel.grid.minor = element_blank()) +
      geom_hline(yintercept = c(0.25, 0.5, 0.75), linetype = "dashed",
                 color = "black", size = 0.5, alpha = 0.3)
    if (save) export_plot(p, "viz_freqs_df", subdir = subdir)
    return(p)
  } else {
    out <- select(out, col, value, count, p) %>%
      rename(n = count, variable = col) %>%
      group_by(variable) %>%
      mutate(pcum = round(cumsum(p), 2))
    return(out)
  }
}


####################################################################
#' Frequencies Plot for Multiple Categories
#' 
#' Plot frequencies of multiple categories within a data.frame in 
#' a new fancy way. Tidyverse friendly, based on lares::freqs().
#' 
#' @family Exploratory
#' @family Visualization
#' @param df Data.frame
#' @param ... Variables. Variables you wish to process. Order matters.
#' If no variables are passed, the whole data.frame will be considered
#' @param top Integer. Filter and plot the most n frequent for  values.
#' @param rm.na Boolean. Remove NA values in the plot? (not filtered for 
#' numerical output; use na.omit() or filter() if needed)
#' @param title Character. Overwrite plot's title with.
#' @param subtitle Character. Overwrite plot's subtitle with.
#' @export
freqs_plot <- function(df, ..., top = 10, rm.na = FALSE, 
                       title = NA, subtitle = NA) {
  
  vars <- quos(...)
  
  if (length(vars) == 0)
    return(freqs(dft))
  
  aux <- df %>% 
    freqs(!!!vars, rm.na = rm.na) %>% 
    mutate_if(is.factor, as.character) %>%
    mutate_if(is.logical, as.character) %>%
    mutate(order = ifelse(order > top, "...", order))
  if ("..." %in% aux$order)
    message(paste(
      "Showing", top, "most frequent values. Tail of",
      nrow(aux) - top,
      "other values grouped into one"))
  for (i in 1:(ncol(aux) - 4))
    aux[,i][aux$order == "...",] <- "Tail"  
  aux <- aux %>%
    group_by(!!!vars, order) %>%
    summarise_all(sum) %>%
    ungroup()
  vars_names <- colnames(aux)[1:(ncol(aux) - 4)]
  
  labels <- aux %>% mutate_all(as.character) %>% 
    tidyr::pivot_longer(colnames(aux)[1:(ncol(aux)-4)]) %>%
    mutate(label = sprintf("%s: %s", name, value)) %>%
    mutate(n = as.integer(n), 
           pcum = as.numeric(pcum),
           p = as.numeric(p)) %>%
    ungroup() %>% arrange(desc(pcum))
  
  if (is.na(title))
    title <- "Absolute Frequencies"
  if (is.na(subtitle))
    subtitle <- paste("Grouped by", vector2text(vars_names, quotes = FALSE))
  mg <- 5
  
  p1 <- aux %>% 
    mutate(aux = ifelse(order == "...", "grey", "black")) %>%
    mutate(order = paste0(order, "\n", signif(as.numeric(p), 2), "%")) %>%
    ggplot(aes(x = reorder(order, pcum), y = n, label = p)) +
    geom_col(aes(fill = aux)) +
    scale_fill_manual(values = c("black", "grey55")) +
    labs(x = NULL, y = NULL, title = title, subtitle = subtitle) + 
    scale_y_comma() +
    guides(fill = FALSE) +
    theme_lares2() +
    theme(plot.margin = margin(mg, mg, 0, mg))
  
  p2 <- labels %>%
    mutate(label = ifelse(order == "...", " Mixed Tail", label)) %>%
    ggplot(aes(x = reorder(order, pcum), 
               y = reorder(label, n), 
               group = pcum)) +
    geom_point(size = 4) +
    labs(x = NULL, y = NULL, 
         caption = paste("Total observations:", formatNum(nrow(df), 0))) + 
    guides(colour = FALSE) +
    theme_lares2(which = "XY") +
    #facet_grid(name ~ ., scales = "free") +
    theme(axis.text.x = element_blank(),
          plot.margin = margin(0, mg, mg, mg))
  if (length(vars) > 1)
    p2 <- p2 + geom_path()
  
  p <- (p1 / p2)
  attr(p, "data") <- aux
  attr(p, "labels") <- labels
  return(p)
}
