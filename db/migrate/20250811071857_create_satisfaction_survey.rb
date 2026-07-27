class CreateSatisfactionSurvey < ActiveRecord::Migration[5.2]
  def up
    # Create the satisfaction survey with questions in a transaction
    survey = nil
    
    ActiveRecord::Base.transaction do
      # Build the survey but don't save yet
      survey = Surveys::Survey.new(
        title: "ENCUESTA DE SATISFACCIÓN",
        description: "¡Gracias por elegir nuestras viandas! Tu opinión es muy importante para nosotros.\nLes solicitamos que completen la siguiente encuesta con objetividad.\nDesde ya, agradecemos su colaboración.",
        active: true,
        tienda_id: 1,
        fecha_desde: Date.current,
        fecha_hasta: Date.current + 1.year
      )

      # Question 1: Scale 1-5 about flavor satisfaction
      survey.questions.build(
        text: "¿Qué tan satisfecho estás con el sabor general de las viandas?",
        question_type: "scale",
        required: true
      )

      # Question 2: Multiple choice - satisfaction (Yes/No)
      question2 = survey.questions.build(
        text: "¿Consideras que la porción es adecuada?",
        question_type: "multiple_choice",
        required: true
      )
      question2.answers.build([
        { text: "SI", value: "si" },
        { text: "No", value: "no" }
      ])

      # Question 3: Multiple choice - menu variety
      question3 = survey.questions.build(
        text: "¿Cómo calificarías la variedad de los menúes?",
        question_type: "multiple_choice",
        required: true
      )
      question3.answers.build([
        { text: "Muy poca", value: "muy_poca" },
        { text: "Suficiente", value: "suficiente" },
        { text: "Mucha", value: "mucha" }
      ])

      # Question 4: Text - ingredients feedback
      survey.questions.build(
        text: "¿Hay algún ingrediente que te gustaría ver más o menos? ¿Cuál?",
        question_type: "text",
        required: false
      )

      # Question 5: Multiple choice - recommendation
      question5 = survey.questions.build(
        text: "¿Recomendarías nuestras viandas a un amigo o familiar?",
        question_type: "multiple_choice",
        required: true
      )
      question5.answers.build([
        { text: "Si", value: "si" },
        { text: "No", value: "no" },
        { text: "Tal vez", value: "tal_vez" }
      ])

      # Question 6: Text - comments
      survey.questions.build(
        text: "COMENTARIOS U OBSERVACIONES",
        question_type: "text",
        required: false
      )

      # Now save the survey with all questions built
      survey.save!
    end

    puts "✅ Satisfaction survey created successfully with ID: #{survey.id}"
    puts "📝 Created #{survey.questions.count} questions"
    puts "🎯 Created #{survey.questions.joins(:answers).count} answer options"
  end

  def down
    # Remove the survey and all related data
    survey = Surveys::Survey.find_by(title: "ENCUESTA DE SATISFACCIÓN", tienda_id: 1)
    if survey
      puts "🗑️  Removing satisfaction survey and all related data..."
      survey.destroy!
      puts "✅ Survey removed successfully"
    else
      puts "⚠️  Survey not found"
    end
  end
end
