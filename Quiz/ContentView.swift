//
//  ContentView.swift
//  Quiz
//
//  Created by daina on 2025/04/07.
//

import SwiftUI

struct ContentView: View {
    @State private var category: String = "地理"
    @State private var quizQuestions: [QuizQuestion] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentQuestionIndex = 0
    @State private var userAnswers: [Int] = []
    @State private var quizCompleted = false
    @State private var questionCount: Int = 5  // デフォルトは5問
    
    let categories = ["地理", "動物", "歴史", "科学"]
    let questionCountOptions = [3, 5, 10, 15]  // 問題数のオプション
    
    var body: some View {
        NavigationView {
            ZStack {
                // バックグラウンドカラー（オプション）
                Color(UIColor.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                if isLoading {
                    ProgressView("クイズを読み込んでいます...")
                } else if let errorMessage = errorMessage {
                    // エラーが発生した場合
                    VStack {
                        Text("エラー: \(errorMessage)")
                            .foregroundColor(.red)
                            .padding()
                        Button("最初の画面に戻る") {
                            self.quizQuestions = []
                            self.errorMessage = nil
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                } else if quizQuestions.isEmpty {
                    // クイズがまだ生成されていない場合
                    VStack {
                        Text("カテゴリを選択")
                            .font(.headline)
                            .padding(.top)
                        
                        Picker("カテゴリを選択", selection: $category) {
                            ForEach(categories, id: \.self) { category in
                                Text(category)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                        
                        Text("問題数を選択")
                            .font(.headline)
                            .padding(.top)
                        
                        Picker("問題数を選択", selection: $questionCount) {
                            ForEach(questionCountOptions, id: \.self) { count in
                                Text("\(count)問")
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                        
                        Button("クイズを生成") {
                            loadQuizQuestions()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 20)
                    }
                    .padding()
                } else if quizCompleted {
                    // クイズが完了した場合、ここでNavigationTitleを明示的に空にする
                    ResultView(
                        quizQuestions: quizQuestions,
                        userAnswers: userAnswers,
                        onRestart: {
                            // クイズをリセット
                            quizQuestions = []
                            userAnswers = []
                            currentQuestionIndex = 0
                            quizCompleted = false
                        }
                    )
                    .navigationBarTitle("", displayMode: .inline)
                } else {
                    // クイズの問題と選択肢を表示
                    QuestionView(
                        question: quizQuestions[currentQuestionIndex],
                        questionNumber: currentQuestionIndex + 1,
                        totalQuestions: quizQuestions.count,
                        onAnswerSelected: { selectedIndex in
                            // 選択された回答を記録
                            userAnswers.append(selectedIndex)
                            
                            // 次の問題へ進むか、クイズを完了する
                            if currentQuestionIndex < quizQuestions.count - 1 {
                                currentQuestionIndex += 1
                            } else {
                                quizCompleted = true
                            }
                        }
                    )
                }
            }
            .navigationTitle(quizCompleted ? "" : "クイズアプリ")
        }
    }
    
    private func loadQuizQuestions() {
        isLoading = true
        errorMessage = nil
        userAnswers = []
        currentQuestionIndex = 0
        quizCompleted = false
        
        let quizService = QuizService()
        quizService.generateQuizQuestions(category: category, count: questionCount) { quizzes, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = "クイズの生成に失敗しました: \(error.localizedDescription)"
                    print("Error: \(error.localizedDescription)")
                    return
                }
                
                if let quizzes = quizzes {
                    quizQuestions = quizzes
                } else {
                    errorMessage = "クイズの生成に失敗しました。"
                }
            }
        }
    }
}

// 問題と選択肢表示用のビュー
struct QuestionView: View {
    let question: QuizQuestion
    let questionNumber: Int  // 現在の問題番号
    let totalQuestions: Int  // 全問題数
    let onAnswerSelected: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 問題番号と進捗を表示
            Text("問題 \(questionNumber)/\(totalQuestions)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top)
            
            Text(question.question)
                .font(.title3)
                .padding(.bottom)
            
            Text("選択肢")
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(0..<question.options.count, id: \.self) { index in
                    Button(action: {
                        onAnswerSelected(index)
                    }) {
                        HStack {
                            Text("\(index + 1). \(question.options[index])")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// 結果表示用のビュー
struct ResultView: View {
    let quizQuestions: [QuizQuestion]
    let userAnswers: [Int]
    let onRestart: () -> Void
    
    var correctAnswersCount: Int {
        var count = 0
        for (index, question) in quizQuestions.enumerated() {
            if index < userAnswers.count && question.correctAnswerIndex == userAnswers[index] {
                count += 1
            }
        }
        return count
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("クイズ結果")
                    .font(.title)
                    .padding()
                
                Text("正解数: \(correctAnswersCount)/\(quizQuestions.count)")
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 15) {
                    ForEach(0..<quizQuestions.count, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("問題 \(index + 1): \(quizQuestions[index].question)")
                                .font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("あなたの回答: \(index < userAnswers.count ? quizQuestions[index].options[userAnswers[index]] : "未回答")")
                                .foregroundColor(index < userAnswers.count && userAnswers[index] == quizQuestions[index].correctAnswerIndex ? .green : .red)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("正解: \(quizQuestions[index].options[quizQuestions[index].correctAnswerIndex])")
                                .foregroundColor(.green)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.bottom, 10)
                    }
                }
                .padding(.horizontal)
                
                Button("もう一度プレイ") {
                    onRestart()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.vertical, 20)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
