//
//  QuizService.swift
//  Quiz
//
//  Created by daina on 2025/04/07.
//

import Foundation

// クイズ問題の構造体
struct QuizQuestion: Identifiable, Decodable {
    var id: UUID = UUID() // 自動的に一意なIDを生成
    var question: String
    var options: [String]
    var correctAnswerIndex: Int

    enum CodingKeys: String, CodingKey {
        case question
        case options
        case correctAnswerIndex
    }
}

// OpenAIのAPIを使用してクイズ問題を生成するクラス
class QuizService {
    
    private var apiKey: String {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "QuizAPIKey") as? String else {
            fatalError("APIキーが設定されていません。")
        }
        return apiKey
    }

    func generateQuizQuestions(category: String, count: Int, completion: @escaping ([QuizQuestion]?, Error?) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            print("Invalid URL")
            completion(nil, NSError(domain: "QuizService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // プロンプト作成
        let prompt = """
        次の形式で\(category)に関する\(count)問のクイズを作成してください。選択肢は4つで、1つが正解です。
        JSON形式で問題を返してください。他の文章は一切含めないでください。
        [
            {
                "question": "問題文",
                "options": ["選択肢1", "選択肢2", "選択肢3", "選択肢4"],
                "correctAnswerIndex": 正解のインデックス（0から3の数値）
            }
        ]
        """

        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "あなたはクイズ生成AIです。JSON形式でのみ応答してください。余分な説明や文章は返さず、純粋なJSON配列のみを返してください。"],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData

            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("API request failed: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }

                guard let data = data else {
                    print("No data received")
                    completion(nil, NSError(domain: "QuizService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                    return
                }

                // レスポンス確認
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        
                        print("Response content: \(content)") // レスポンス内容をデバッグ出力
                        var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

                        // 余分な文字列を削除
                        if !cleanedContent.starts(with: "[") {
                            if let jsonStart = cleanedContent.range(of: "["),
                               let jsonEnd = cleanedContent.range(of: "]", options: .backwards) {
                                cleanedContent = String(cleanedContent[jsonStart.lowerBound...jsonEnd.upperBound])
                            }
                        }

                        // JSONデコード
                        let decoder = JSONDecoder()
                        if let jsonData = cleanedContent.data(using: .utf8) {
                            do {
                                let quizzes = try decoder.decode([QuizQuestion].self, from: jsonData)
                                completion(quizzes, nil)
                            } catch {
                                print("JSON Decoding Error: \(error.localizedDescription)")
                                print("Failed content: \(cleanedContent)")
                                completion(nil, error)
                            }
                        } else {
                            print("Failed to convert cleaned content to data")
                            completion(nil, NSError(domain: "QuizService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert cleaned content to data"]))
                        }

                    } else {
                        print("Invalid response format")
                        completion(nil, NSError(domain: "QuizService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"]))
                    }
                } catch {
                    print("JSON Parsing Error: \(error.localizedDescription)")
                    completion(nil, error)
                }
            }
            task.resume()
        } catch {
            print("Request Body Encoding Error: \(error.localizedDescription)")
            completion(nil, error)
        }
    }
}
