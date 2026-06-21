//
//  Homography.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//
import Foundation
import simd

struct Homography {

    static func mapping(from source: [CGPoint], to destination: [CGPoint]) -> simd_float3x3 {
        precondition(source.count == 4 && destination.count == 4)

        var matrix = Array(
            repeating: Array(repeating: Float(0), count: 9),
            count: 8
        )

        for index in 0..<4 {
            let src = source[index]
            let dst = destination[index]
            let u = Float(src.x)
            let v = Float(src.y)
            let x = Float(dst.x)
            let y = Float(dst.y)

            let row = index * 2
            matrix[row] = [u, v, 1, 0, 0, 0, -x * u, -x * v, x]
            matrix[row + 1] = [0, 0, 0, u, v, 1, -y * u, -y * v, y]
        }

        let solution = solveLinearSystem(matrix)
        return simd_float3x3(rows: [
            SIMD3(solution[0], solution[1], solution[2]),
            SIMD3(solution[3], solution[4], solution[5]),
            SIMD3(solution[6], solution[7], 1)
        ])
    }

    private static func solveLinearSystem(_ augmentedMatrix: [[Float]]) -> [Float] {
        precondition(augmentedMatrix.count == 8)
        precondition(augmentedMatrix.allSatisfy { $0.count == 9 })

        var matrix = augmentedMatrix
        let dimension = 8

        for pivot in 0..<dimension {
            var pivotRow = pivot
            var pivotValue = abs(matrix[pivot][pivot])

            for candidate in (pivot + 1)..<dimension {
                let value = abs(matrix[candidate][pivot])
                if value > pivotValue {
                    pivotValue = value
                    pivotRow = candidate
                }
            }

            if pivotRow != pivot {
                matrix.swapAt(pivot, pivotRow)
            }

            let divisor = matrix[pivot][pivot]
            guard abs(divisor) > 0.000001 else {
                return [1, 0, 0, 0, 1, 0, 0, 0]
            }

            for column in pivot...dimension {
                matrix[pivot][column] /= divisor
            }

            for row in 0..<dimension where row != pivot {
                let factor = matrix[row][pivot]
                guard factor != 0 else { continue }
                for column in pivot...dimension {
                    matrix[row][column] -= factor * matrix[pivot][column]
                }
            }
        }

        return (0..<dimension).map { matrix[$0][dimension] }
    }
}
