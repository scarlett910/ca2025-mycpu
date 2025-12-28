// SPDX-License-Identifier: MIT
// Branch Penalty Measurement - Single-Cycle CPU

package riscv.singlecycle

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import riscv.TestAnnotations

class BranchPenaltyTest extends AnyFlatSpec with ChiselScalatestTester {
  behavior.of("Single Cycle CPU - Branch Penalty Measurement")
  
  it should "measure execution cycles for Fibonacci" in {
    test(new TestTopModule("fibonacci.asmbin"))
      .withAnnotations(TestAnnotations.annos) { c =>
      
      // Disable timeout
      c.clock.setTimeout(0)
      
      var cycles = 0
      var done = false
      val maxCycles = 100000
      
      println("\n" + "="*70)
      println("SINGLE-CYCLE CPU - Cycle Measurement")
      println("="*70)
      println("Program: fibonacci.asmbin (recursive fib(10))")
      println("Expected result: 55")
      println("-"*70)
      
      // Run simulation
      while (!done && cycles < maxCycles) {
        c.clock.step(1)
        cycles += 1
        
        // Check completion every 100 cycles
        if (cycles % 100 == 0) {
          c.io.mem_debug_read_address.poke(4.U)
          c.clock.step()
          val result = c.io.mem_debug_read_data.peekInt()
          
          if (result == 55) {
            done = true
          }
        }
        
        // Progress
        if (cycles % 10000 == 0) {
          println(s"  ... $cycles cycles")
        }
      }
      
      // Final check
      c.io.mem_debug_read_address.poke(4.U)
      c.clock.step()
      val finalResult = c.io.mem_debug_read_data.peekInt()
      
      println()
      println("="*70)
      println("RESULTS:")
      println("="*70)
      println(f"Status:       ${if (done) "✓ PASS" else "✗ FAIL"}")
      println(f"Cycles:       $cycles%,d")
      println(f"Result:       $finalResult (expected: 55)")
      println("="*70)
      
      if (done) {
        println()
        println("✓ Single-Cycle measurement complete")
        println(f"✓ Record this number: $cycles cycles")
        println()
        
        // Save to file
        val writer = new java.io.PrintWriter("/tmp/branch_penalty_results.txt")
        try {
          writer.println(f"Single-Cycle: $cycles cycles")
        } finally {
          writer.close()
        }
        println("✓ Result saved to: /tmp/branch_penalty_results.txt")
      }
      
      println("="*70 + "\n")
      
      // Verify
      assert(done, "Should complete within cycle limit")
      assert(finalResult == 55, "Result should be 55")
    }
  }
}
