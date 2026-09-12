# Tạo hình tóm tắt cho README từ bộ dữ liệu chính của phần Data 2.
# Chạy từ bất kỳ thư mục nào bằng:
# Rscript analysis/create_portfolio_figures.R

invisible(Sys.setlocale("LC_CTYPE", "English_United States.utf8"))

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})

command_args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", command_args, value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1]]))
repo_dir <- normalizePath(file.path(dirname(script_path), ".."))

data_path <- file.path(repo_dir, "data", "student_habits_performance.csv")
output_dir <- file.path(repo_dir, "output", "figures")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

student_data <- read.csv(data_path, stringsAsFactors = TRUE)
stopifnot(
  nrow(student_data) == 1000,
  !anyDuplicated(student_data$student_id),
  !anyNA(student_data),
  all(student_data$exam_score >= 0 & student_data$exam_score <= 100)
)
student_data$student_id <- NULL

categorical_vars <- c(
  "gender", "parental_education_level", "diet_quality", "internet_quality",
  "part_time_job", "extracurricular_participation"
)
student_data[categorical_vars] <- lapply(student_data[categorical_vars], factor)

model_full <- lm(exam_score ~ ., data = student_data)
student_data$fitted_score <- fitted(model_full)

model_summary <- summary(model_full)
r_squared <- model_summary$r.squared
adjusted_r_squared <- model_summary$adj.r.squared

p_fit <- ggplot(student_data, aes(x = fitted_score, y = exam_score)) +
  geom_point(alpha = 0.45, size = 1.7, color = "#1f77b4") +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "#d62728") +
  annotate(
    "label",
    x = Inf,
    y = -Inf,
    hjust = 1.05,
    vjust = -0.6,
    label = sprintf("Trong mẫu: R² = %.3f\nAdjusted R² = %.3f", r_squared, adjusted_r_squared),
    size = 3.7
  ) +
  labs(
    title = "Điểm quan sát và điểm ước lượng",
    subtitle = "Đường đứt nét biểu diễn dự báo hoàn hảo",
    x = "Điểm ước lượng từ mô hình",
    y = "Điểm thi quan sát"
  ) +
  theme_minimal(base_size = 12)

numeric_predictors <- c(
  "age", "study_hours_per_day", "social_media_hours", "netflix_hours",
  "attendance_percentage", "sleep_hours", "exercise_frequency",
  "mental_health_rating"
)

standardized_data <- student_data
standardized_data[c("exam_score", numeric_predictors)] <-
  lapply(standardized_data[c("exam_score", numeric_predictors)], scale)
standardized_data$fitted_score <- NULL

standardized_model <- lm(exam_score ~ ., data = standardized_data)
coefficient_matrix <- summary(standardized_model)$coefficients
confidence_intervals <- confint(standardized_model)

coefficient_data <- data.frame(
  variable = rownames(coefficient_matrix),
  estimate = coefficient_matrix[, "Estimate"],
  p_value = coefficient_matrix[, "Pr(>|t|)"],
  lower = confidence_intervals[, 1],
  upper = confidence_intervals[, 2],
  row.names = NULL
)

coefficient_data <- coefficient_data[
  coefficient_data$variable %in% numeric_predictors & coefficient_data$p_value < 0.05,
]

display_labels <- c(
  study_hours_per_day = "Giờ học mỗi ngày",
  social_media_hours = "Thời gian mạng xã hội",
  netflix_hours = "Thời gian Netflix",
  attendance_percentage = "Tỷ lệ chuyên cần",
  sleep_hours = "Thời gian ngủ",
  exercise_frequency = "Tần suất vận động",
  mental_health_rating = "Sức khỏe tinh thần"
)

coefficient_data$label <- unname(display_labels[coefficient_data$variable])
coefficient_data$label <- reorder(coefficient_data$label, coefficient_data$estimate)

p_coef <- ggplot(coefficient_data, aes(x = estimate, y = label)) +
  geom_vline(xintercept = 0, color = "grey55", linetype = "dashed") +
  geom_errorbar(
    aes(xmin = lower, xmax = upper),
    orientation = "y",
    width = 0.16,
    color = "#4c566a"
  ) +
  geom_point(aes(color = estimate > 0), size = 2.8) +
  scale_color_manual(values = c(`TRUE` = "#2a9d8f", `FALSE` = "#e76f51"), guide = "none") +
  labs(
    title = "Các hệ số chuẩn hóa có ý nghĩa thống kê",
    subtitle = "Ước lượng và khoảng tin cậy 95%; đã kiểm soát các biến còn lại",
    x = "Thay đổi độ lệch chuẩn của điểm thi",
    y = NULL
  ) +
  theme_minimal(base_size = 12)

overview <- p_fit | p_coef
overview <- overview + plot_annotation(
  title = "Tóm tắt mô hình hồi quy tuyến tính bội",
  subtitle = "Dữ liệu mô phỏng; kết quả thể hiện mối liên hệ, không chứng minh nhân quả"
)

ggsave(
  filename = file.path(output_dir, "regression-overview.png"),
  plot = overview,
  width = 14,
  height = 7,
  dpi = 180,
  bg = "white"
)

message("Đã tạo: ", file.path(output_dir, "regression-overview.png"))
