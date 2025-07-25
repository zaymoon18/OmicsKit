######################
# Function nice_UMAP #
######################

#' Function to make UMAP plots.
#'
#' @param object A matrix of counts with genes as rows and sample ids as columns.
#' @param annotations A data frame of annotation, including sample ids and variables to plot. Default: NULL.
#' @param neighbors Number of nearest neighbors to consider. Default: 5.
#' @param components Number of components to be consider for the dimensional reduction. Default: 3.
#' @param epochs Number of iterations. Default: 10000.
#' @param seed Set a random seed state. Default: 0.
#' @param variables To indicate the variables to be used as Shape and Fill of the markers.
#' @param legend_names The names to be used for the legend of the Shape and Fill.
#' @param size Size of the marker. Default: 5.
#' @param alpha Transparency of the marker, which goes from 0 (transparent) to 1 (no transparent). Default: 1.
#' @param colors Vector of colors to be used for the categories of the variable assigned as VarFill.
#' @param shapes Vector of shapes to be used for the categories of the variable assigned as VarShape.
#' @param title Plot title. Default: NULL.
#' @param legend_title Font of the legend title. Default: 16.
#' @param legend_elements Font of the elements of the legend Default: 14.
#' @param legend_pos Position of the legend inside the plot. Example: c(0.80, 0.80). Default: NULL.
#' @param labels A vector containing the variable to be used as labels (name inside the marker), and the label size. Example: c(var = "patient", size = 2). Default: NULL (no labels).
#' @param name_tags A vector containing the variable to be used as name tags (name outside the marker), tag size, minimum distance in order to add an arrow connecting the tag and the marker, and minimum distance from the tag and the center of the marker. Example: c(var = "label", size = 3, minlen = 2, box = 0.5). Default: NULL (no name tags).
#' @param cluster_data Indicates if the function generates the clusters (TRUE) or not (FALSE). This new cluster variable can be used as fill or shape. Default: FALSE.
#' @param min_points Minimum number of neighbors to form a cluster. Default: 7.
#' @param transform Logical. Indicates whether to log2 transform the input `object` or not. Default: FALSE.
#' @param returnData Indicates if the function should return the data (TRUE) or the plot (FALSE). Default: FALSE.
#' @import ggplot2
#' @importFrom magrittr %>%
#' @importFrom rlang .data
#' @export

nice_UMAP <- function(object, annotations = NULL, neighbors = 5, components = 2, epochs = 10000, seed = 0,
                      variables = c(fill = "VarFill", shape = "VarShape"),
                      legend_names = c(fill = "Label Fill", shape = "Label Shape"),
                      size = 5, alpha = 1, colors = NULL, shapes = NULL, title = NULL,
                      legend_title = 16, legend_elements = 14, legend_pos = NULL,
                      labels = NULL, name_tags = NULL, cluster_data = FALSE,
                      min_points = 7, transform = FALSE, returnData = FALSE)

{

  if (!requireNamespace("umap", quietly = TRUE)) {
    stop(
      "Package \"umap\" must be installed to use this function.",
      call. = FALSE
      )
  }

  expr <- if (transform) log2(object + 0.001) else object

  # Initialize umap
  umap.params = umap::umap.defaults
  umap.params$n_neighbors=neighbors
  umap.params$n_components=components
  umap.params$n_epochs=epochs
  umap.params$random_state=seed
  umap.params$transform_state=seed
  umap.params$verbose=TRUE

  # Create data frame
  umap_data <- umap::umap(t(expr), config = umap.params, preserve.seed = TRUE)
  colnames(umap_data$layout) <- c("X1", "X2")

  if (returnData) {
    return(umap_data)
  }

  if (is.null(annotations)) {
    stop("`annotations` must be supplied when returnData = FALSE", call. = FALSE)
  }

  if (cluster_data) {
    if (!requireNamespace("dbscan", quietly = TRUE)) {
      stop(
        "Package \"dbscan\" must be installed to perform clustering.",
        call. = FALSE
      )
    }

    # Perform HDBSCAN clustering
    cl <- dbscan::hdbscan(t(expr), minPts = min_points)$cluster
    names(cl) <- colnames(expr)

    # Add cluster labels to annotations
    annotations$cluster <- factor(cl[annotations$id])
  }

  df.umap <- as.data.frame(umap_data$layout) %>%
    tibble::rownames_to_column(var = "id") %>%
    dplyr::inner_join(annotations, by = "id")

  # Create plot
  if (length(variables) == 3) {

    if (!requireNamespace("ggnewscale", quietly = TRUE)) {
      stop(
        "Package \"ggnewscale\" must be installed for third variable aesthetics.",
        call. = FALSE
      )
    }

    p.umap <- ggplot(data = df.umap, aes(x = .data[["X1"]], y = .data[["X2"]], fill = .data[[variables[3]]])) +
      stat_ellipse(geom = "polygon", alpha = 0.2) + scale_fill_manual(name = legend_names[3], values = c("orange", "thistle4", "yellow")) +

      ggnewscale::new_scale_fill() +

      geom_point(aes(fill = .data[[variables[1]]], shape = .data[[variables[2]]]), size = size, alpha = alpha) +
      scale_shape_manual(name = legend_names[2], values = shapes,
                         guide  = guide_legend(override.aes = list(size = 7), keyheight = 1.7))

    if (is.numeric(df.umap[[variables[1]]])) {
      p.umap <- p.umap + scale_fill_gradient2(name = legend_names[1], low = "blue", mid = "white", high = "red")
    } else {
      p.umap <- p.umap + scale_fill_manual(name = legend_names[1], values = colors,
                                           guide = guide_legend(override.aes = aes(size = 7, shape = 21)))
    }

  } else if (length(variables) == 2) {
    p.umap <- ggplot(data = df.umap, aes(x = .data[["X1"]], y = .data[["X2"]], fill = .data[[variables[1]]], shape = .data[[variables[2]]])) +
      geom_point(size = size, alpha = alpha) + labs(fill = legend_names[1], shape = legend_names[2]) +
      scale_shape_manual(values = shapes, guide = guide_legend(override.aes = list(size = 7), keyheight = 1.7))

    if (is.numeric(df.umap[[variables[1]]])) {
      p.umap <- p.umap + scale_fill_gradient2(low = "blue", mid = "white", high = "red")
    } else {
      p.umap <- p.umap + scale_fill_manual(values = colors, guide = guide_legend(override.aes = aes(shape = 21, size = 7)))
    }

  } else if (length(variables) == 1) {
    p.umap <- ggplot(data = df.umap, aes(x = .data[["X1"]], y = .data[["X2"]], fill = .data[[variables[1]]])) +
      geom_point(size = size, alpha = alpha, shape = 21) + labs(fill = legend_names)

    if (is.numeric(df.umap[[variables]])) {
      p.umap <- p.umap + scale_fill_gradient2(low = "blue", mid = "white", high = "red")
    } else {
      p.umap <- p.umap + scale_fill_manual(values = colors, guide = guide_legend(override.aes = aes(size = 7)))
    }
  }

  p.umap <- p.umap + coord_fixed() + theme_bw()

  if (!is.null(title)) {
    p.umap <- p.umap + labs(title = title) + theme(plot.title = element_text(size = 18, hjust = 0.5))
  }

  p.umap <- p.umap + theme(axis.text = element_blank(), axis.title = element_blank(),
                           legend.title = element_text(size = legend_title),
                           legend.text = element_text(size = legend_elements))

  if (is.null(legend_pos) == FALSE) {
    p.umap <- p.umap + theme(legend.background = element_rect(color = "black"), legend.position = "inside",
                             legend.position.inside = c(legend_pos[1], legend_pos[2]))
  }

  # Manage labels and tags
  if (is.null(labels) == FALSE) {
    if (length(labels) == 1) {
      lab_size <- as.numeric(labels)
      df.umap$label <- seq_len(nrow(df.umap))
    } else {
      lab_var <- labels[1]
      if (!lab_var %in% names(df.umap)) {
        stop("`labels[1]` must be a column in `annotations`")
      }
      lab_size <- labels[2]
      df.umap$label <- df.umap[[lab_var]]
    }

    # Add the labels to the plot
    p.umap <- p.umap +
      geom_text(data = df.umap, aes(label = .data[["label"]]), color = "black", size = lab_size)
  }

  if(is.null(name_tags) == FALSE) {

    if (!requireNamespace("ggrepel", quietly = TRUE)) {
      stop(
        "Package \"ggrepel\" must be installed to annotate plot.",
        call. = FALSE
        )
    }

    if (length(name_tags) == 1) {
      tag_var <- "id"
      tag_size <- as.numeric(name_tags)
      minlen <- 2
      boxpad <- 0.5
    } else {
      tag_var <- name_tags[1]
      if (!tag_var %in% names(df.umap)) {
        stop("`name_tags[1]` must be a column in `annotations`")
      }
      tag_size <- as.numeric(name_tags[2])
      minlen <- as.numeric(name_tags[3])
      boxpad <- as.numeric(name_tags[4])
    }

    # Add the column of name tags to the data frame
    df.umap$tag <- df.umap[[tag_var]]

    # Add the name tags to the plot
    p.umap <- p.umap +
      ggrepel::geom_text_repel(data = df.umap, aes(label = .data[["tag"]]), color = "black", size = tag_size,
                               min.segment.length = unit(minlen, "lines"), box.padding = unit(boxpad, "lines"))
  }

  return(p.umap)
}
