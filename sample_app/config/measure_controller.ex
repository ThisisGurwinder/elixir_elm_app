defmodule TsWeb.MeasureController do
  @moduledoc false
  use TsWeb.Web, :controller
  use ControllerSetup
  alias Platform.Crypto
  alias Platform.Mapping

  alias TsWeb.{
    ComparisonTypeView,
    CourseView,
    DataView,
    FileView,
    MeasurementView,
    MeasureView,
    TermView
  }

  def create_old_measureworkflow(conn, params, %{
        "UserId" => member_id,
        "OaId" => oa_id
      }) do
    %{"terms" => terms} = params

    with {:ok, created_measure} <-
           PlanningService.create_measure_for_planoutcome_old_measureworkflow(
             params,
             member_id,
             oa_id,
             &PlanningALT.create_measure/3
           ),
         {:ok, _measure_period} <-
           PlanningService.create_measure_period(
             created_measure.id,
             terms,
             oa_id,
             &PlanningALT.create_measure_period/1
           ),
         {:ok, _} <-
           PlanningService.update_memberid_planoutcome(
             created_measure.plan_outcome_id,
             member_id,
             &PlanningALT.update_member_id_in_plan_outcome/2
           ) do
      conn
      |> put_status(:created)
      |> render(DataView, "id.json", id: created_measure.id)
    end
  end

  def create_update_measure(conn, params, %{
        "UserId" => member_id,
        "OaId" => oa_id
      }) do
    %{"terms" => terms, "plan_outcome_id" => plan_outcome_id, "course_id" => course_id} = params

    selected_file_ids = Map.get(params, "file_ids", [])

    with {:ok, created_measure} <-
           PlanningService.create_measure_for_planoutcome(
             params,
             member_id,
             oa_id,
             &PlanningALT.create_measure_for_planoutcome/5,
             &PlanningALT.get_measure_terms/1
           ),
         {:ok, _} <-
           PlanningService.update_memberid_planoutcome(
             created_measure.plan_outcome_id,
             member_id,
             &PlanningALT.update_member_id_in_plan_outcome/2
           ),
         {:ok, _} <-
           PlanningService.save_measure_files(
             created_measure.id,
             selected_file_ids,
             &PlanningALT.get_file_item_ids/1,
             &PlanningALT.save_measure_files/3
           ),
         {:ok, _} <-
           OrganizationService.update_course_outcome_alignment_on_measure_update(
             plan_outcome_id,
             course_id,
             oa_id,
             %{
               :fn_get_curriculum_map_courses_by_course_ids =>
                 &Core.get_curriculum_map_courses_by_course_ids/2,
               :fn_get_curriculum_map_outcomes_by_outcome_ids =>
                 &Core.get_curriculum_map_outcomes_by_outcome_ids/1,
               :fn_get_course_outcome_alignments => &Core.get_course_outcome_alignments/3,
               :fn_insert_course_outcome_alignment => &Core.insert_course_outcome_alignment/5
             },
             %{
               :fn_get_outcome_id => &PlanningALT.get_outcome_id/1
             }
           ) do
      conn
      |> put_status(:created)
      |> render(DataView, "id.json", id: created_measure.id)
    end
  end

  def get_outcome_terms(conn, params, %{"OaId" => oa_id}) do
    with {:ok, selected_terms} <-
           params
           |> Map.get("planOutcomeId")
           |> Crypto.decrypt_int()
           |> PlanningService.get_outcome_terms(
             oa_id,
             &PlanningALT.get_plan_session_for_oa_and_plan_outcome/2,
             &Core.get_session_terms_by_ids/1
           ) do
      render(conn, TermView, "index.json", terms: selected_terms)
    end
  end

  def create_measurement(conn, params, %{"UserId" => member_id}) do
    %{"plan_outcome_id" => plan_outcome_id} = params

    function_map = %{
      f_create_letter_grade: &PlanningALT.create_letter_grade/3,
      f_create_points_score_setting: &PlanningALT.create_points_score_setting/1,
      f_create_measurement: &PlanningALT.create_measurement/1
    }

    rubric_map = %{
      f_save_measurement: &PlanningALT.save_measurement/1,
      f_save_rubric: &PlanningALT.save_rubric/1,
      f_save_measurement_rubric: &PlanningALT.save_measurement_rubric/1,
      f_save_criteria: &PlanningALT.save_criteria/1,
      f_save_criteria_level: &PlanningALT.save_criteria_level/1,
      f_delete_criteria_level_by_criteria_ids:
        &PlanningALT.delete_criteria_level_by_criteria_ids/1,
      f_delete_criteria_by_criteria_ids: &PlanningALT.delete_criteria_by_criteria_ids/1
    }

    with {:ok, created_measurement} <-
           PlanningService.create_measurement(params, function_map, rubric_map),
         {:ok, _} <-
           PlanningService.update_memberid_planoutcome(
             plan_outcome_id,
             member_id,
             &PlanningALT.update_member_id_in_plan_outcome/2
           ) do
      conn
      |> put_status(:created)
      |> render(MeasurementView, "show.json", measurement: created_measurement)
    end
  end

  def save_measurement_request_results(conn, params, _claims) do
    with {:ok, created_measurement} <-
           PlanningService.save_measurement_request_results(
             params,
             &PlanningALT.create_measurement/1
           ) do
      conn
      |> put_status(:created)
      |> render(DataView, "id.json", id: created_measurement.id)
    end
  end

  def fetch_measurement(conn, %{"measurementId" => measurement_id}, _claims) do
    with {:ok, measurement} <-
           measurement_id
           |> Crypto.decrypt_int()
           |> PlanningService.fetch_measurement(&PlanningALT.fetch_measurement/1) do
      render(conn, "measurement_details.json", res: %{"data" => measurement})
    end
  end

  def get_comparison_types(conn, _params, _claims) do
    with {:ok, comparison_types} <-
           PlanningService.get_comparison_types(&PlanningALT.get_comparison_types/0) do
      render(
        conn,
        ComparisonTypeView,
        "index.json",
        comparison_types: comparison_types
      )
    end
  end

  def update_measurement(conn, params, %{"UserId" => member_id}) do
    %{"plan_outcome_id" => plan_outcome_id} = params

    letter_grade_functions = %{
      delete_previous_letter_grade: &PlanningALT.delete_previous_letter_grade/2,
      update_measurement_create_letter_grade:
        &PlanningALT.update_measurement_create_letter_grade/3,
      get_measurement_score_ranges: &PlanningALT.get_measurement_score_ranges/1,
      get_measurement_scoretype: &PlanningALT.get_measurement_scoretype/1,
      get_datacollection_format: &PlanningALT.get_datacollection_format/1
    }

    points_percentage_map = %{
      delete_previous_points_percentage: &PlanningALT.delete_previous_points_percentage/1,
      update_measurement_create_points_score_setting:
        &PlanningALT.update_measurement_create_points_score_setting/1,
      get_score_setting_id: &PlanningALT.get_score_setting_id/1,
      delete_previous_measurement: &PlanningALT.delete_previous_measurement/1
    }

    rubric_map = %{
      f_save_measurement: &PlanningALT.save_measurement/1,
      f_save_rubric: &PlanningALT.save_rubric/1,
      f_save_measurement_rubric: &PlanningALT.save_measurement_rubric/1,
      f_save_criteria: &PlanningALT.save_criteria/1,
      f_save_criteria_level: &PlanningALT.save_criteria_level/1,
      f_delete_criteria_level_by_criteria_ids:
        &PlanningALT.delete_criteria_level_by_criteria_ids/1,
      f_delete_criteria_by_criteria_ids: &PlanningALT.delete_criteria_by_criteria_ids/1
    }

    with {:ok, updated_measurement} <-
           PlanningService.update_measurement(
             params,
             letter_grade_functions,
             points_percentage_map,
             rubric_map
           ),
         {:ok, _} <-
           PlanningService.update_memberid_planoutcome(
             plan_outcome_id,
             member_id,
             &PlanningALT.update_member_id_in_plan_outcome/2
           ) do
      conn
      |> put_status(:created)
      |> render(MeasurementView, "show.json", measurement: updated_measurement)
    end
  end

  def get_measurement(conn, %{"measureId" => measure_id}, _claims) do
    {:ok, measurement} =
      measure_id
      |> Crypto.decrypt_int()
      |> PlanningService.get_measurement(&PlanningALT.get_measurement/1)

    render(conn, "measurement_title.json", res: %{"result" => measurement})
  end

  # credo:disable-for-next-line Credo.Check.Refactor.ABCSize
  def get_measure_details_old_workflow(conn, params, %{"OaId" => oa_id}) do
    %{"measureId" => measure_id, "measurementId" => measurement_id} = params

    {:ok, measure_details} =
      measure_id
      |> Crypto.decrypt_int()
      |> PlanningService.get_measure_details_old_workflow(
        &PlanningALT.get_measure_details_old_workflow/1
      )

    %{plan_outcome_id: plan_outcome_id, course_id: course_id} = measure_details

    {:ok, measure_terms} =
      measure_id
      |> Crypto.decrypt_int()
      |> PlanningService.get_measure_terms(&PlanningALT.get_measure_terms/1)

    measure_terms_list =
      measure_terms
      |> Enum.map(& &1.term_id)

    {:ok, measure_terms} =
      OrganizationService.get_session_terms_by_ids(
        oa_id,
        measure_terms_list,
        &Core.get_session_terms_by_ids/2,
        format_date: false
      )

    {:ok, sections_list} =
      PlanningService.get_course_sections(
        course_id,
        measure_terms_list,
        &Core.get_course_sections/2
      )

    section_id_list = Enum.map(sections_list, fn section -> section.id end)

    {:ok, section_enrollments_list} =
      section_id_list
      |> PlanningService.get_section_enrollments(&Core.get_section_enrollments_with_term/1)

    {:ok, plan_outcome} =
      plan_outcome_id
      |> PlanningService.get_plan_outcome(&PlanningALT.get_plan_outcome/1)

    %{outcome_id: outcome_id} = plan_outcome

    {:ok, outcome} =
      outcome_id
      |> PlanningService.get_outcome_title(&Core.get_outcome_title/1)

    {:ok, course} =
      oa_id
      |> PlanningService.get_course_by_id(course_id, &Core.get_course_by_id/2)

    {:ok, measurement} =
      measurement_id
      |> Crypto.decrypt_int()
      |> PlanningService.fetch_measurement(&PlanningALT.fetch_measurement/1)

    {:ok, student_results} =
      measurement_id
      |> Crypto.decrypt_int()
      |> PlanningService.get_student_results_of_measurement_id(
        &PlanningALT.get_student_results_of_measurement_id/1
      )

    {:ok, aggregate_results} =
      measurement_id
      |> Crypto.decrypt_int()
      |> PlanningService.get_aggregate_results(&PlanningALT.get_aggregate_results/1)

    result = %{
      "measure_details" => measure_details,
      "sections_list" => sections_list,
      "section_enrollments_list" => section_enrollments_list,
      "measure_terms" => measure_terms,
      "course" => course,
      "outcome" => outcome,
      "measurement" => measurement,
      "student_results" => student_results,
      "aggregate_results" => aggregate_results
    }

    render(conn, "measuredetails_old_workflow.json", res: %{"result" => result})
  end

  # credo:disable-for-next-line Credo.Check.Refactor.ABCSize
  def get_measure_details_preview(
        conn,
        %{"measureId" => measure_id, "measurementId" => measurement_id},
        %{"OaId" => oa_id}
      ) do
    {:ok, measure_details} =
      measure_id
      |> Crypto.decrypt_int()
      |> PlanningService.get_measure_details_old_workflow(
        &PlanningALT.get_measure_details_old_workflow/1
      )

    %{plan_outcome_id: plan_outcome_id, course_id: course_id} = measure_details

    {:ok, measure_terms} =
      measure_id
      |> Crypto.decrypt_int()
      |> PlanningService.get_measure_terms(&PlanningALT.get_measure_terms/1)

    measure_terms_list = Enum.map(measure_terms, fn term -> term.term_id end)

    {:ok, measure_terms} =
      measure_terms_list
      |> PlanningService.get_terms_for_measurement_preview(
        &Core.get_terms_for_measurement_preview/1
      )

    measure_terms_list = Enum.map(measure_terms, fn term -> term.term_id end)

    {:ok, sections_list} =
      PlanningService.get_course_sections(
        course_id,
        measure_terms_list,
        &Core.get_course_sections/2
      )

    {:ok, plan_outcome} =
      plan_outcome_id
      |> PlanningService.get_plan_outcome(&PlanningALT.get_plan_outcome/1)

    %{outcome_id: outcome_id} = plan_outcome

    {:ok, outcome} =
      outcome_id
      |> PlanningService.get_outcome_title(&Core.get_outcome_title/1)

    {:ok, course} =
      oa_id
      |> PlanningService.get_course_by_id(course_id, &Core.get_course_by_id/2)

    {:ok, measurement} =
      measurement_id
      |> Crypto.decrypt_int()
      |> PlanningService.fetch_measurement(&PlanningALT.fetch_measurement/1)

    result = %{
      "measure_details" => measure_details,
      "sections_list" => sections_list,
      "measure_terms" => measure_terms,
      "course" => course,
      "outcome" => outcome,
      "measurement" => measurement
    }

    render(conn, "measuredetailspreview.json", res: %{"data" => result})
  end

  def save_students_result(conn, params, %{
        "UserId" => member_id,
        "OaId" => oa_id
      }) do
    %{"studentScores" => student_scores} = params
    %{"measurementId" => measurement_id} = params
    %{"planOutcomeId" => plan_outcome_id} = params
    %{"termWisedCounts" => term_wised_counts} = params

    measurement_id =
      measurement_id
      |> Crypto.decrypt_int()

    plan_outcome_id =
      plan_outcome_id
      |> Crypto.decrypt_int()

    with {:ok, _student_scores} <-
           PlanningService.save_students_result(
             measurement_id,
             student_scores,
             oa_id,
             &PlanningALT.save_students_result/1
           ),
         {:ok, _} <-
           PlanningService.update_memberid_planoutcome(
             plan_outcome_id,
             member_id,
             &PlanningALT.update_member_id_in_plan_outcome/2
           ),
         {:ok, _} <-
           PlanningService.save_aggregate_results(
             term_wised_counts,
             &PlanningALT.save_aggregate_results/1
           ) do
      conn
      |> put_status(:created)
      |> send_resp(201, "ScoresSaved")
    end
  end

  def save_students_rubric_result(conn, params, %{
        "UserId" => member_id,
        "OaId" => oa_id
      }) do
    %{"studentScores" => student_scores} = params
    %{"measurementId" => measurement_id} = params
    %{"planOutcomeId" => plan_outcome_id} = params
    %{"termWisedCounts" => term_wised_counts} = params
    %{"rubricId" => rubric_id} = params

    measurement_id =
      measurement_id
      |> Crypto.decrypt_int()

    rubric_id =
      rubric_id
      |> Crypto.decrypt_int()

    plan_outcome_id =
      plan_outcome_id
      |> Crypto.decrypt_int()

    with {:ok, _student_scores} <-
           PlanningService.save_students_rubric_result(
             measurement_id,
             student_scores,
             oa_id,
             plan_outcome_id,
             rubric_id,
             &PlanningALT.save_student_rubric_result/1
           ),
         {:ok, _} <-
           PlanningService.update_memberid_planoutcome(
             plan_outcome_id,
             member_id,
             &PlanningALT.update_member_id_in_plan_outcome/2
           ),
         {:ok, _} <-
           PlanningService.save_aggregate_results(
             term_wised_counts,
             &PlanningALT.save_aggregate_results/1
           ) do
      conn
      |> put_status(:created)
      |> send_resp(201, "RubricScoresSaved")
    end
  end

  def get_measure(conn, %{"measureId" => measure_id}, _claims) do
    {:ok, measure} =
      measure_id
      |> Crypto.decrypt_int()
      |> PlanningService.get_measure(&PlanningALT.get_measure/1)

    %{plan_outcome_id: plan_outcome_id} = measure

    {:ok, %{plan_id: plan_id}} =
      plan_outcome_id
      |> PlanningService.get_plan_outcome(&PlanningALT.get_plan_outcome/1)

    {:ok, measure_terms} =
      measure_id
      |> Crypto.decrypt_int()
      |> PlanningService.get_measure_terms(&PlanningALT.get_measure_terms/1)

    result = %{
      "measure" => measure,
      "plan_id" => plan_id,
      "measure_terms" => measure_terms
    }

    render(conn, "measure.json", res: %{"result" => result})
  end

  def get_term_ids_for_score_result_entered(
        conn,
        %{"measurementId" => measurement_id},
        _claims
      ) do
    {:ok, score_inputs} =
      measurement_id
      |> Crypto.decrypt_int()
      |> PlanningService.get_student_results(&PlanningALT.get_student_results/1)

    section_ids = Enum.map(score_inputs, fn score -> score[:section_id] end)

    {:ok, term_ids_list} =
      section_ids
      |> PlanningService.get_terms_for_org_nodes(&Core.get_terms_for_org_nodes/1)

    result = %{"term_ids_list" => term_ids_list}
    render(conn, "measureDisabledTerms.json", res: %{"result" => result})
  end

  def get_scoretypes(conn, _params, _claims) do
    {:ok, score_type} = PlanningALT.get_scoretypes()
    render(conn, "scoretype.json", res: %{"result" => score_type})
  end

  def update_measure(conn, params, %{"UserId" => member_id, "OaId" => oa_id}) do
    %{"terms" => terms} = params

    with {:ok, created_measure} <-
           PlanningService.update_measure(
             params,
             &PlanningALT.update_measure/1
           ),
         {:ok, _num_records_deleted} <-
           PlanningService.delete_all_measure_periods_of_measure_id(
             created_measure.id,
             &PlanningALT.delete_all_measure_periods_of_measure_id/1
           ),
         {:ok, _measure_period} <-
           PlanningService.create_measure_period(
             created_measure.id,
             terms,
             oa_id,
             &PlanningALT.create_measure_period/1
           ),
         {:ok, _} <-
           PlanningService.update_memberid_planoutcome(
             created_measure.plan_outcome_id,
             member_id,
             &PlanningALT.update_member_id_in_plan_outcome/2
           ) do
      conn
      |> put_status(:created)
      |> render(DataView, "id.json", id: created_measure.id)
    end
  end

  def update_measurement_calculation_setting(conn, params, %{
        "UserId" => member_id
      }) do
    update_measurement_functions = %{
      update_measurement: &PlanningALT.update_measurement/1,
      create_measurement_calculation_setting:
        &PlanningALT.create_measurement_calculation_setting/2,
      update_measurement_calculation_setting:
        &PlanningALT.update_measurement_calculation_setting/2,
      get_proficiency_levels: &PlanningALT.get_proficiency_levels/0,
      get_measurement_score_range: &PlanningALT.get_measurement_score_range/1,
      reset_measurement_score_range_setting: &PlanningALT.reset_measurement_score_range_setting/1,
      update_measurement_score_range: &PlanningALT.update_measurement_score_range/2,
      f_save_measurement_rubric: &PlanningALT.save_measurement_rubric/1
    }

    %{"plan_outcome_id" => plan_outcome_id} = params

    with {:ok, updated_measurement} <-
           PlanningService.update_measurement_calculation_setting_points(
             params,
             update_measurement_functions
           ),
         {:ok, update_measurement_score_range} <-
           PlanningService.update_measurement_calculation_setting_grade(
             params,
             &PlanningALT.update_measurement/1,
             &PlanningALT.get_proficiency_levels/0,
             &PlanningALT.create_update_letter_grade_success_setting/4,
             &PlanningALT.reset_measurement_score_range_setting/1
           ),
         {:ok, _} <-
           PlanningService.update_memberid_planoutcome(
             plan_outcome_id,
             member_id,
             &PlanningALT.update_member_id_in_plan_outcome/2
           ) do
      if is_nil(updated_measurement) do
        render(
          conn,
          "calculation_setting.json",
          res: update_measurement_score_range
        )
      else
        render(conn, "calculation_setting.json", res: updated_measurement)
      end
    end
  end

  def publish_measurement(conn, params, %{"UserId" => member_id}) do
    measurement_id =
      params
      |> Map.get("measurementId")
      |> Crypto.decrypt_int()

    plan_outcome_id =
      params
      |> Map.get("planOutcomeId")
      |> Crypto.decrypt_int()

    with {:ok, _} <-
           PlanningService.publish_measurement(
             measurement_id,
             &PlanningALT.publish_measurement/1
           ),
         {:ok, _} <-
           PlanningService.update_memberid_planoutcome(
             plan_outcome_id,
             member_id,
             &PlanningALT.update_member_id_in_plan_outcome/2
           ) do
      conn |> render("publish_measurement.json", res: "published")
    end
  end

  def save_measure_result(conn, params, %{
        "UserId" => member_id,
        "OaId" => oa_id
      }) do
    with {:ok, updated_measure} <-
           PlanningService.update_measure(
             params,
             &PlanningALT.update_measure/1
           ),
         {:ok, _} <-
           PlanningService.update_memberid_planoutcome(
             updated_measure.plan_outcome_id,
             member_id,
             &PlanningALT.update_member_id_in_plan_outcome/2
           ) do
      conn
      |> put_status(:created)
      |> render(DataView, "id.json", id: updated_measure.id)
    end
  end

  def get_proficiency_levels(conn, _params, _claims) do
    {:ok, proficiency_levels} =
      PlanningService.get_proficiency_levels(&PlanningALT.get_proficiency_levels/0)

    render(conn, "proficiency_levels.json", res: proficiency_levels)
  end

  def get_score_calculation_types(conn, _params, _claims) do
    {:ok, score_calculation_types} =
      PlanningService.get_score_calculation_types(&PlanningALT.get_score_calculation_types/0)

    render(conn, "score_calculation_types.json", res: score_calculation_types)
  end

  def get_measure_details_aggregate(conn, params, %{"OaId" => oa_id}) do
    %{"measureId" => measure_id, "measurementId" => measurement_id} = params

    {:ok, measure_details} =
      measure_id
      |> Crypto.decrypt_int()
      |> PlanningService.get_measure_details_old_workflow(
        &PlanningALT.get_measure_details_old_workflow/1
      )

    %{course_id: course_id} = measure_details

    {:ok, measure_terms} =
      measure_id
      |> Crypto.decrypt_int()
      |> PlanningService.get_measure_terms(&PlanningALT.get_measure_terms/1)

    measure_terms_list =
      measure_terms
      |> Enum.map(& &1.term_id)

    {:ok, course} =
      oa_id
      |> PlanningService.get_course_by_id(course_id, &Core.get_course_by_id/2)

    {:ok, measurement} =
      measurement_id
      |> Crypto.decrypt_int()
      |> PlanningService.fetch_measurement(&PlanningALT.fetch_measurement/1)

    {:ok, terms} =
      OrganizationService.get_session_terms_by_ids(
        oa_id,
        measure_terms_list,
        &Core.get_session_terms_by_ids/2,
        format_date: false
      )

    {:ok, aggregate_results} =
      measurement_id
      |> Crypto.decrypt_int()
      |> PlanningService.get_aggregate_results(&PlanningALT.get_aggregate_results/1)

    result = %{
      "measure_details" => measure_details,
      "measure_terms" => terms,
      "course" => course,
      "measurement" => measurement,
      "aggregate_results" => aggregate_results
    }

    render(conn, "measuredetails_aggregate.json", res: result)
  end

  def is_data_associated(conn, params, _claims) do
    %{"measure_id" => measure_id} = params

    with {:ok, measure} <- PlanningService.get_measure(measure_id, &PlanningALT.get_measure/1),
         {:ok, measurement} <-
           PlanningService.get_measurement(
             measure_id,
             &PlanningALT.get_measurement/1
           ) do
      if is_nil(measurement) and is_nil(measure.is_result_met) and is_nil(measure.analyze_result) and
           is_nil(measure.met_students_count) and is_nil(measure.not_met_students_count) do
        conn
        |> render(
          MeasureView,
          "data-associated.json",
          res: %{
            id: measure_id,
            is_data_associated: false
          }
        )
      else
        conn
        |> render(
          MeasureView,
          "data-associated.json",
          res: %{
            id: measure_id,
            is_data_associated: true
          }
        )
      end
    end
  end

  def delete_measure(conn, params, _claims) do
    %{"measure_id" => measure_id} = params

    with {:ok, measure} <- PlanningService.get_measure(measure_id, &PlanningALT.get_measure/1) do
      {:ok, measurement} =
        PlanningService.get_measurement(
          measure_id,
          &PlanningALT.get_measurement/1
        )

      if is_nil(measurement) do
        with {:ok, _} <-
               PlanningService.delete_measure(
                 measure_id,
                 &PlanningALT.delete_measure/1
               ) do
          conn
          |> render(
            MeasureView,
            "res.json",
            res: %{data: Mapping.encrypt_map(measure, :measure, false)}
          )
        end
      else
        with {:ok, _} <-
               PlanningService.delete_measure_data(
                 measure_id,
                 measurement.id,
                 &PlanningALT.delete_measure_data/2
               ) do
          conn
          |> render(
            MeasureView,
            "res.json",
            res: %{data: Mapping.encrypt_map(measure, :measure, false)}
          )
        end
      end
    end
  end

  def get_result_granularity_types(conn, _params, _claims) do
    {:ok, result_granularity_types} =
      PlanningService.get_result_granularity_types(&PlanningALT.get_result_granularity_types/0)

    render(
      conn,
      "result_granularity_types.json",
      res: %{"result" => result_granularity_types}
    )
  end

  def save_aggregate_results(con, params, _claims) do
    %{"aggregate_results" => aggregate_results} = params

    with {:ok, _result} <-
           aggregate_results
           |> PlanningService.save_aggregate_results(&PlanningALT.save_aggregate_results/1) do
      con
      |> put_status(:created)
      |> render("res.json", res: %{"data" => "ResultsSaved"})
    end
  end

  def get_measure_details(conn, params, %{"OaId" => oa_id}) do
    %{"measureId" => measure_id} = params

    with {:ok, measure_details} <-
           measure_id
           |> Crypto.decrypt_int()
           |> PlanningService.get_measure_details(&PlanningALT.get_measure_details/1),
         {:ok, measure_terms} <-
           measure_id
           |> Crypto.decrypt_int()
           |> PlanningService.get_measure_terms(&PlanningALT.get_measure_terms/1),
         measure_terms_list <-
           measure_terms
           |> Enum.map(& &1.term_id),
         {:ok, terms} <-
           OrganizationService.get_session_terms_by_ids(
             oa_id,
             measure_terms_list,
             &Core.get_session_terms_by_ids/2,
             format_date: false
           ),
         {:ok, course} <-
           oa_id
           |> PlanningService.get_course_by_id(
             measure_details[:course_id],
             &Core.get_course_by_id/2
           ) do
      result = %{
        "measure_details" => measure_details,
        "measure_terms" => terms,
        "course" => course
      }

      conn
      |> render(
        MeasureView,
        "measure_details.json",
        res: result
      )
    end
  end

  def create_input_measurement_request_results(conn, params, _claims) do
    with {:ok, measure} <-
           PlanningService.update_measure(
             params,
             &PlanningALT.update_measure/1
           ) do
      conn
      |> put_status(:created)
      |> render(DataView, "id.json", id: measure.id)
    end
  end

  def get_outcome_from_plan_outcome(conn, params, _claims) do
    %{"planOutcomeId" => plan_outcome_id} = params

    {:ok, outcome} =
      plan_outcome_id
      |> Crypto.decrypt_int()
      |> PlanningService.get_outcome_from_plan_outcome(
        &PlanningALT.get_outcome_id/1,
        &Core.get_outcome_by_id/1
      )

    render(conn, MeasureView, "outcome.json", res: outcome)
  end

  def get_measure_course_association_types(conn, _params, _claims) do
    with {:ok, measure_course_association_types} <-
           PlanningService.get_measure_course_association_types(
             &PlanningALT.get_measure_course_association_types/0
           ) do
      render(
        conn,
        MeasureView,
        "measure_course_association_types.json",
        res: measure_course_association_types
      )
    end
  end

  def get_outcome_courses(conn, params, claims) do
    with {:ok, courses} <-
           PlanningService.get_outcome_courses(
             claims["OaId"],
             params["org_node_id"],
             &Core.get_org_node_with_descendants/2,
             &Core.get_curriculum_courses_for_measure/2
           ) do
      render(conn, CourseView, "index-sort-by-code.json", courses: courses)
    end
  end

  def get_measurement_request_result(conn, params, _claims) do
    with {:ok, measure} <-
           PlanningService.get_measurement_request_result(
             params["measure_id"],
             &PlanningALT.get_measurement_request_result/1
           ) do
      render(conn, MeasureView, "measurement-request-result.json", measure: measure)
    end
  end

  def get_docs(conn, params, claims) do
    result =
      PlanningService.get_files_for_measure(
        claims["OaId"],
        params["measure_id"],
        &PlanningALT.get_file_item_ids/1,
        &Core.get_file_items_from_ids/2
      )

    with {:ok, file_items} <- result, do: render(conn, FileView, "index.json", files: file_items)
  end

  def get_aggregate_results(conn, params, _claims) do
    function_map = %{
      f_get_course_sections: &Core.get_course_sections/2,
      f_get_aggregate_results_by_term: &PlanningALT.get_aggregate_results_by_term/2
    }

    with {:ok, aggregate_results} <-
           PlanningService.get_aggregate_results_by_term(params, function_map) do
      render(
        conn,
        MeasureView,
        "aggregate_results_by_term.json",
        aggregate_results: aggregate_results
      )
    end
  end

  def get_measure_details_manage_results(conn, params, %{"OaId" => oa_id}) do
    %{"measure_id" => measure_id} = params

    core_functions_map = %{
      f_get_session_terms_by_ids: &Core.get_session_terms_by_ids/2,
      f_get_course_by_id: &Core.get_course_by_id/2
    }

    planning_functions_map = %{
      f_get_measure_details: &PlanningALT.get_measure_details/1,
      f_get_measure_terms: &PlanningALT.get_measure_terms/1,
      f_get_aggregate_results_counts_per_term:
        &PlanningALT.get_aggregate_results_counts_per_term/1
    }

    with {:ok, measure_details} <-
           measure_id
           |> PlanningService.get_measure_details_manage_results(
             oa_id,
             core_functions_map,
             planning_functions_map
           ) do
      conn
      |> render(
        MeasureView,
        "measure_details_manage_results.json",
        res: measure_details
      )
    end
  end

  def get_result_percentages(conn, params, _claims) do
    %{"measure_id" => measure_id} = params

    with {:ok, result} <-
           measure_id
           |> PlanningService.get_result_percentages(&PlanningALT.get_met_notmet_result/1) do
      conn |> render(MeasureView, "result_percentages.json", res: result)
    end
  end
end
