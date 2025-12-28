// SPDX-License-Identifier: MIT
// Branch Penalty Measurement - All Pipeline Implementations

package riscv

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class BranchPenaltyTest extends AnyFlatSpec with ChiselScalatestTester {
  behavior.of("Pipeline - Cycle Measurement")
  
  // Test tất cả 4 implementations
  for (config <- PipelineConfigs.All) {
    it should s"measure cycles for Fibonacci (${config.name})" in {
      test(new TestTopModule("fibonacci.asmbin", config.implementation))
        .withAnnotations(TestAnnotations.annos) { c =>
        
        c.clock.setTimeout(0)
        
        var cycles = 0
        var done = false
        
        println("\n" + "="*70)
        println(s"${config.name}")
        println("="*70)
        
        // Run until done
        while (!done && cycles < 200000) {
          c.clock.step(1)
          cycles += 1
          
          if (cycles % 100 == 0) {
            c.io.mem_debug_read_address.poke(4.U)
            c.clock.step()
            if (c.io.mem_debug_read_data.peekInt() == 55) {
              done = true
            }
          }
          
          if (cycles % 20000 == 0) println(s"  ... $cycles cycles")
        }
        
        println()
        println("="*70)
        println(f"RESULT: $cycles%,d cycles")
        println("="*70)
        println()
        
        // Save
        val w = new java.io.PrintWriter(
          new java.io.FileOutputStream("/tmp/pipeline_results.txt", true)
        )
        w.println(f"${config.name}: $cycles cycles")
        w.close()
        
        assert(done)
      }
    }
  }
}
