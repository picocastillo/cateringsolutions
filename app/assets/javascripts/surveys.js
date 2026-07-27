// Survey Management JavaScript
// Uses App.onMount for Turbolinks compatibility

App.onMount('.surveys-edit-form, .surveys-new-form', function() {
  console.log('Survey edit/new page loaded');
  
  let questionIndex = parseInt(document.querySelector('#questions-container').dataset.questionIndex || '0', 10);
  let answerIndex = 0;
  console.log('Current question index:', questionIndex);
  
  // Calculate initial answer index based on existing answers
  document.querySelectorAll('.answer-field').forEach(function() {
    answerIndex++;
  });
  
  const addButton = document.getElementById('add-question');
  const container = document.getElementById('questions-container');
  
  if (!addButton) {
    console.error('Add question button not found!');
    return;
  }
  
  if (!container) {
    console.error('Questions container not found!');
    return;
  }
  
  // Set the question index on the container for future reference
  container.dataset.questionIndex = questionIndex;
  
  // Handle question type changes for existing and new questions
  container.addEventListener('change', function(e) {
    if (e.target.classList.contains('question-type-select')) {
      handleQuestionTypeChange(e.target);
    }
  });
  
  // Function to handle question type changes
  function handleQuestionTypeChange(selectElement) {
    const questionField = selectElement.closest('.question-field');
    const answersSection = questionField.querySelector('.answers-section');
    
    if (selectElement.value === 'multiple_choice') {
      answersSection.style.display = 'block';
      // Add at least one answer option if none exist
      const answersContainer = answersSection.querySelector('.answers-container');
      if (answersContainer.children.length === 0) {
        addAnswerOption(answersContainer, questionField.dataset.questionIndex || getQuestionIndex(questionField));
      }
    } else {
      answersSection.style.display = 'none';
    }
  }
  
  // Function to get question index from form field names
  function getQuestionIndex(questionField) {
    const textarea = questionField.querySelector('textarea[name*="questions_attributes"]');
    if (textarea) {
      const match = textarea.name.match(/questions_attributes\]\[(\d+)\]/);
      return match ? match[1] : questionIndex;
    }
    return questionIndex;
  }
  
  // Function to add answer option
  function addAnswerOption(container, qIndex) {
    const answerHtml = `
      <div class="answer-field input-group mb-2">
        <input type="text" 
               name="survey[questions_attributes][${qIndex}][answers_attributes][${answerIndex}][text]" 
               class="form-control" 
               placeholder="Texto de la opción">
        <input type="hidden" 
               name="survey[questions_attributes][${qIndex}][answers_attributes][${answerIndex}][value]" 
               value="${answerIndex + 1}">
        <div class="input-group-append">
          <button type="button" class="btn btn-outline-danger remove-answer">
            <i class="fa fa-trash"></i>
          </button>
        </div>
        <input type="hidden" 
               name="survey[questions_attributes][${qIndex}][answers_attributes][${answerIndex}][_destroy]" 
               value="false" 
               class="answer-destroy-field">
      </div>
    `;
    container.insertAdjacentHTML('beforeend', answerHtml);
    answerIndex++;
  }
  
  // Handle add answer button clicks
  container.addEventListener('click', function(e) {
    if (e.target.closest('.add-answer')) {
      e.preventDefault();
      const questionField = e.target.closest('.question-field');
      const answersContainer = questionField.querySelector('.answers-container');
      const qIndex = questionField.dataset.questionIndex || getQuestionIndex(questionField);
      addAnswerOption(answersContainer, qIndex);
    }
  });
  
  // Handle remove answer button clicks
  container.addEventListener('click', function(e) {
    if (e.target.closest('.remove-answer')) {
      e.preventDefault();
      const answerField = e.target.closest('.answer-field');
      const destroyField = answerField.querySelector('.answer-destroy-field');
      
      if (destroyField) {
        destroyField.value = 'true';
        answerField.style.display = 'none';
      } else {
        answerField.remove();
      }
    }
  });
  
  // Handle add question button clicks
  addButton.addEventListener('click', function(e) {
    e.preventDefault();
    console.log('Add question button clicked, adding question with index:', questionIndex);
    
    const questionHtml = `
      <div class="question-field card mb-3" data-question-index="${questionIndex}">
        <div class="card-body">
          <div class="d-flex justify-content-between align-items-start mb-3">
            <h6 class="card-title mb-0">Pregunta ${questionIndex + 1}</h6>
            <button type="button" class="btn btn-outline-danger btn-sm remove-question">
              <i class="fa fa-trash"></i>
              Eliminar
            </button>
          </div>
          
          <div class="form-group">
            <label class="form-label">Texto de la pregunta</label>
            <textarea name="survey[questions_attributes][${questionIndex}][text]" 
                      class="form-control" 
                      placeholder="Escriba su pregunta aquí" 
                      rows="2"></textarea>
          </div>
          
          <div class="row">
            <div class="col-md-6">
              <div class="form-group">
                <label class="form-label">Tipo de pregunta</label>
                <select name="survey[questions_attributes][${questionIndex}][question_type]" 
                        class="form-control question-type-select">
                  <option value="">Seleccione un tipo</option>
                  <option value="text">Texto libre</option>
                  <option value="multiple_choice">Opción múltiple</option>
                  <option value="scale">Escala (1-5)</option>
                </select>
              </div>
            </div>
            
            <div class="col-md-6">
              <div class="form-group">
                <label class="form-label">Opciones</label>
                <div class="form-check">
                  <input type="hidden" 
                         name="survey[questions_attributes][${questionIndex}][required]" 
                         value="false">
                  <input type="checkbox" 
                         name="survey[questions_attributes][${questionIndex}][required]" 
                         class="form-check-input" 
                         id="survey_questions_attributes_${questionIndex}_required"
                         value="true">
                  <label class="form-check-label" 
                         for="survey_questions_attributes_${questionIndex}_required">
                    Pregunta obligatoria
                  </label>
                </div>
              </div>
            </div>
          </div>
          
          <!-- Answer Options Section -->
          <div class="answers-section" style="display: none;">
            <hr class="my-3">
            <div class="d-flex justify-content-between align-items-center mb-2">
              <h6 class="mb-0">
                <i class="fa fa-list"></i>
                Opciones de Respuesta
              </h6>
              <button type="button" class="btn btn-outline-success btn-sm add-answer">
                <i class="fa fa-plus"></i>
                Agregar Opción
              </button>
            </div>
            
            <div class="answers-container">
              <!-- Answers will be added here dynamically -->
            </div>
          </div>
          
          <!-- Hidden field for destroy -->
          <input type="hidden" 
                 name="survey[questions_attributes][${questionIndex}][_destroy]" 
                 value="false" 
                 class="destroy-field">
        </div>
      </div>
    `;
    
    container.insertAdjacentHTML('beforeend', questionHtml);
    questionIndex++;
    container.dataset.questionIndex = questionIndex;
    console.log('Question added successfully, new index:', questionIndex);
  });
  
  // Handle remove question buttons
  container.addEventListener('click', function(e) {
    if (e.target.closest('.remove-question')) {
      e.preventDefault();
      console.log('Remove question button clicked');
      
      const questionField = e.target.closest('.question-field');
      const destroyField = questionField.querySelector('.destroy-field');
      
      if (destroyField) {
        destroyField.value = 'true';
        questionField.style.display = 'none';
        console.log('Question marked for destruction');
      } else {
        questionField.remove();
        console.log('Question removed from DOM');
      }
    }
  });
  
  // Initialize existing questions
  document.querySelectorAll('.question-type-select').forEach(function(select) {
    handleQuestionTypeChange(select);
  });
});

// Survey Response Form JavaScript
App.onMount('#survey-response-new', function() {
  console.log('Survey response form loaded');
  
  const form = document.querySelector('form');
  
  if (form) {
    // Handle scale question styling only
    const scaleGroups = form.querySelectorAll('.btn-group-toggle');
    scaleGroups.forEach(function(group) {
      const radioButtons = group.querySelectorAll('input[type="radio"]');
      const labels = group.querySelectorAll('label');
      
      radioButtons.forEach(function(radio, index) {
        radio.addEventListener('change', function() {
          // Remove active class from all labels
          labels.forEach(function(label) {
            label.classList.remove('active');
          });
          
          // Add active class to selected label
          if (this.checked) {
            labels[index].classList.add('active');
          }
        });
      });
    });
  }
});

// Survey Response Show/Index JavaScript
App.onMount('#survey-responses-index, #survey-responses-show', function() {
  console.log('Survey responses page loaded');
  console.log('WordCloud library available:', typeof WordCloud !== 'undefined');
  
  // Handle delete confirmations
  const deleteLinks = document.querySelectorAll('a[data-confirm]');
  deleteLinks.forEach(function(link) {
    link.addEventListener('click', function(e) {
      const confirmMessage = this.getAttribute('data-confirm');
      if (!confirm(confirmMessage)) {
        e.preventDefault();
      }
    });
  });
  
  // Handle progress bars animation
  const progressBars = document.querySelectorAll('.progress-bar');
  progressBars.forEach(function(bar) {
    const targetWidth = bar.getAttribute('aria-valuenow') + '%';
    setTimeout(function() {
      bar.style.width = targetWidth;
    }, 100);
  });
  
  // Handle statistics cards animation
  const statCards = document.querySelectorAll('.stat-card .card-text');
  statCards.forEach(function(card) {
    const finalValue = parseInt(card.textContent);
    if (!isNaN(finalValue)) {
      let currentValue = 0;
      const increment = Math.ceil(finalValue / 20);
      const timer = setInterval(function() {
        currentValue += increment;
        if (currentValue >= finalValue) {
          currentValue = finalValue;
          clearInterval(timer);
        }
        card.textContent = currentValue;
      }, 50);
    }
  });

  // Initialize word clouds for text questions
  console.log('Looking for text data elements...');
  document.querySelectorAll('[id^="text-data-"]').forEach(function(element) {
    const questionId = element.id.split('-')[2];
    const textData = element.getAttribute('data-text');
    const canvasId = 'wordcloud-' + questionId;
    const canvas = document.getElementById(canvasId);
    
    console.log('Processing question', questionId, {
      textData: textData ? textData.substring(0, 100) + '...' : 'EMPTY',
      textLength: textData ? textData.length : 0,
      canvasFound: !!canvas,
      wordCloudAvailable: typeof WordCloud !== 'undefined'
    });
    
    if (textData && textData.trim().length > 0 && canvas) {
      const wordList = processTextToWordCloud(textData);
      console.log('Word list generated:', wordList.length > 0 ? wordList.slice(0, 10) : 'EMPTY');
      console.log('Actual word data:', wordList.map(item => `"${item[0]}" (${item[1]})`).join(', '));
      
      if (wordList.length > 0) {
        if (typeof WordCloud !== 'undefined') {
          try {
            // Set canvas size explicitly
            canvas.width = canvas.offsetWidth || 400;
            canvas.height = canvas.offsetHeight || 220;
            
            console.log('Canvas dimensions:', canvas.width, 'x', canvas.height);
            
            WordCloud(canvas, {
              list: wordList,
              gridSize: Math.max(Math.round(16 * canvas.width / 1024), 4),
              weightFactor: function (size) {
                // Much simpler and more predictable weight calculation
                return size * 15; // Base size multiplied by frequency
              },
              fontFamily: 'Arial, sans-serif',
              color: function (word, weight) {
                // Generate colors based on weight
                const colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd', '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf'];
                return colors[Math.floor(Math.random() * colors.length)];
              },
              backgroundColor: 'transparent',
              rotateRatio: 0.3,
              rotationSteps: 2,
              minSize: 12,
              maxSize: 60,
              drawOutOfBound: false,
              shrinkToFit: true
            });
            console.log('Word cloud generated successfully for question', questionId);
          } catch (e) {
            console.error('Error generating word cloud:', e);
            // Fallback: show word frequency list
            showWordFrequencyFallback(canvas, wordList);
          }
        } else {
          console.warn('WordCloud library not available, using fallback');
          showWordFrequencyFallback(canvas, wordList);
        }
      } else {
        console.log('No significant words found for question', questionId);
        // Show message when no significant words found
        const context = canvas.getContext('2d');
        context.font = '14px Arial';
        context.fillStyle = '#666';
        context.textAlign = 'center';
        context.fillText('No hay palabras significativas para mostrar', canvas.width / 2, canvas.height / 2);
      }
    } else if (canvas && (!textData || textData.trim().length === 0)) {
      console.log('No text data for question', questionId);
      // Show empty state message
      const context = canvas.getContext('2d');
      context.font = '14px Arial';
      context.fillStyle = '#999';
      context.textAlign = 'center';
      context.fillText('No hay respuestas de texto disponibles', canvas.width / 2, canvas.height / 2);
    }
  });

  // Render Chart.js charts for multiple-choice question aggregates
  if (typeof Chart !== 'undefined') {
    var elements = document.querySelectorAll('[id^="mc-q-"]');
    Array.prototype.forEach.call(elements, function(span) {
      var id = span.id.replace('mc-q-', '');
      var labels = span.dataset.labels;
      var datos = span.dataset.datos;
      try {
        labels = Array.isArray(labels) ? labels : JSON.parse(labels);
      } catch (e) { labels = []; }
      try {
        datos = Array.isArray(datos) ? datos : JSON.parse(datos);
      } catch (e) { datos = []; }

      // Normalize datos to a flat number array
      if (Array.isArray(datos) && datos.length > 0 && Array.isArray(datos[0])) {
        datos = datos[0];
      }
      datos = (datos || []).map(function(n) { return typeof n === 'number' ? n : parseFloat(n || 0); });

      // Basic guards
      var target = document.getElementById('ct-q-' + id);
      if (!target || labels.length === 0 || datos.length === 0) { return; }
      if (labels.length !== datos.length) {
        // Align lengths by trimming to the shortest
        var len = Math.min(labels.length, datos.length);
        labels = labels.slice(0, len);
        datos = datos.slice(0, len);
      }

      try {
        new Chart(target.getContext('2d'), {
          type: 'bar',
          data: { labels: labels, datasets: [{ data: datos, backgroundColor: 'rgba(0, 158, 251, 0.6)', borderColor: '#009efb', borderWidth: 1 }] },
          options: { responsive: true, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } }
        });
      } catch (e) { /* noop */ }
    });

      // Scale charts
      var scaleElements = document.querySelectorAll('[id^="scale-q-"]');
      Array.prototype.forEach.call(scaleElements, function(span) {
        var id = span.id.replace('scale-q-', '');
        var labels = span.dataset.labels;
        var datos = span.dataset.datos;
        try { labels = Array.isArray(labels) ? labels : JSON.parse(labels); } catch (e) {}
        try { datos = Array.isArray(datos) ? datos : JSON.parse(datos); } catch (e) {}
        var target = document.getElementById('scale-ct-q-' + id);
        if (!target || !labels || !datos) return;
        // Normalize flat numeric series
        if (Array.isArray(datos) && datos.length > 0 && Array.isArray(datos[0])) {
          datos = datos[0];
        }
        datos = (datos || []).map(function(n) { return typeof n === 'number' ? n : parseFloat(n || 0); });
        if (!Array.isArray(labels) || labels.length === 0 || datos.length === 0) return;
        if (labels.length !== datos.length) {
          var len = Math.min(labels.length, datos.length);
          labels = labels.slice(0, len);
          datos = datos.slice(0, len);
        }
        try {
          new Chart(target.getContext('2d'), {
            type: 'bar',
            data: { labels: labels, datasets: [{ data: datos, backgroundColor: 'rgba(0, 158, 251, 0.6)', borderColor: '#009efb', borderWidth: 1 }] },
            options: { responsive: true, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true, max: Math.max.apply(null, datos) || 1 } } }
          });
        } catch (e) { /* noop */ }
      });
  }
});

// Text processing function for word clouds
function processTextToWordCloud(text) {
  console.log('Processing text:', text.substring(0, 200));
  
  // Spanish stop words
  const stopWords = new Set(['el', 'la', 'de', 'que', 'y', 'a', 'en', 'un', 'es', 'se', 'no', 'te', 'lo', 'le', 'da', 'su', 'por', 'son', 'con', 'para', 'al', 'del', 'los', 'las', 'una', 'como', 'muy', 'pero', 'sus', 'cuando', 'sin', 'sobre', 'ser', 'tiene', 'durante', 'todo', 'nos', 'ya', 'también', 'otro', 'hasta', 'hace', 'dos', 'puede', 'sido', 'esta', 'vez', 'este', 'estos', 'estas', 'ese', 'esa', 'esos', 'esas', 'aquel', 'aquella', 'aquellos', 'aquellas', 'mi', 'tu', 'me', 'te', 'nos', 'os', 'le', 'les', 'se', 'más', 'menos', 'tan', 'tanto', 'mucho', 'poco', 'demasiado', 'bastante', 'nada', 'algo', 'alguien', 'nadie', 'alguno', 'ninguno', 'cualquier', 'todo', 'cada', 'otro', 'mismo', 'propio', 'nuevo', 'viejo', 'grande', 'pequeño', 'bueno', 'malo', 'mejor', 'peor', 'donde', 'cuando', 'como', 'porque', 'aunque', 'mientras', 'desde', 'hacia', 'contra', 'entre', 'bajo', 'sobre', 'ante', 'tras', 'mediante', 'durante', 'según', 'excepto', 'salvo', 'incluso', 'además', 'tampoco', 'ni', 'sino', 'pero', 'mas', 'aunque', 'si', 'sí', 'no', 'tal']);

  const words = text.toLowerCase()
    .replace(/[^\w\sáéíóúñü]/gi, '') // Keep Spanish characters
    .split(/\s+/)
    .filter(function(word) { 
      return word.length > 2 && !stopWords.has(word) && !/^\d+$/.test(word); // Also filter pure numbers
    });
  
  console.log('Filtered words:', words.slice(0, 20));
  
  const wordCount = {};
  words.forEach(function(word) {
    wordCount[word] = (wordCount[word] || 0) + 1;
  });
  
  const result = Object.keys(wordCount)
    .map(function(word) { return [word, wordCount[word]]; })
    .sort(function(a, b) { return b[1] - a[1]; })
    .slice(0, 50); // Top 50 words
    
  console.log('Final word list:', result.slice(0, 10));
  return result;
}

// Fallback function when WordCloud library is not available
function showWordFrequencyFallback(canvas, wordList) {
  const context = canvas.getContext('2d');
  context.clearRect(0, 0, canvas.width, canvas.height);
  
  // Set up text properties
  context.font = '12px Arial';
  context.fillStyle = '#333';
  context.textAlign = 'left';
  
  // Display top words as a simple list
  const maxWords = Math.min(wordList.length, 15);
  const lineHeight = Math.min(canvas.height / (maxWords + 1), 20);
  
  context.fillText('Palabras más frecuentes:', 10, lineHeight);
  
  for (let i = 0; i < maxWords; i++) {
    const [word, count] = wordList[i];
    const text = word + ' (' + count + ')';
    context.fillText(text, 20, (i + 2) * lineHeight);
  }
}
