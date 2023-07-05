// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Thomas Benz <tbenz@ethz.ch>


    // write a byte to the AXI-attached memory
    task write_byte_axi_mem (
        input byte_t byte_i,
        input addr_t addr_i
    );
        i_axi_sim_mem.mem[addr_i] = byte_i;
    endtask

    // read a byte from the AXI-attached memory
    task read_byte_axi_mem (
        output byte_t byte_o,
        input  addr_t addr_i
    );
        if (i_axi_sim_mem_delayed.mem.exists(addr_i))
            byte_o = i_axi_sim_mem_delayed.mem[addr_i];
        else
            byte_o = '1;
    endtask

    // write a byte in model memory and AXI-attached memory
    task write_byte_mem (
        input byte_t byte_i,
        input addr_t addr_i
    );
        write_byte_axi_mem (byte_i, addr_i);
        model.write_byte   (byte_i, addr_i);
    endtask

    // set error flag in the AXI-attached memory
    task set_error_mem (
        input addr_t          addr_i,
        input logic           is_read_i,
        input axi_pkg::resp_t resp_i
    );
        if (is_read_i)
            i_axi_sim_mem.rerr[addr_i] = resp_i;
        else
            i_axi_sim_mem.werr[addr_i] = resp_i;
    endtask

    // compare if a byte is equal
    task compare_byte (
        input  addr_t addr_i,
        output logic  match_o
    );
        byte_t axi_byte;
        byte_t model_byte;
        read_byte_axi_mem (axi_byte,   addr_i);
        model_byte = model.read_byte (addr_i);
        match_o = axi_byte === model_byte;
        if (Debug)
            $display("[tb  ] compare: %h - %h - match: %b", axi_byte, model_byte, match_o);
    endtask

    // compare if a range of bytes matches
    task compare_mem (
        input  addr_t length_i,
        input  addr_t addr_i,
        output logic  match_o
    );
        byte_t axi_byte;
        byte_t model_byte;
        addr_t now;
        logic  local_match;
        logic  local_x;
        now = 0;
        match_o = 1;
        while (now < length_i) begin
            read_byte_axi_mem (axi_byte, addr_i + now);
            // omit check against ff (DMA init memory state to simplify error model - ideally this will be rewritten at some point)
            if (axi_byte === 8'hff) begin
                if (Debug)
                    $display("[tb  ] omit check against 0xff @0x%h", addr_i + now);
                now++;
                continue;
            end
            model_byte = model.read_byte (addr_i + now);
            // check if match
            local_match = (axi_byte == model_byte);
            // check if at least a bit is 'x
            local_x = 1'b0;
            for (int i = 0; i < 8; i++)
                local_x = local_x | (axi_byte[i] === 1'bx);
            // global match flag for the burst
            match_o = match_o & local_match & !local_x;
            if (Debug)
                $display("[tb  ] compare:    %h - %h @0x%h - (idma - model - addr) - match: %b", axi_byte, model_byte, addr_i + now, local_match);
            if (!local_match)
                $display("[tb  ] mismatch:   %h - %h @0x%h - (idma - model - addr) - match: %b", axi_byte, model_byte, addr_i + now, local_match);
            if (local_x)
                $display("[tb  ] idma has x: %h (%b) - %h @0x%h - (idma - model - addr) - match: %b", axi_byte, axi_byte, model_byte, addr_i + now, local_match);
            now++;
        end
    endtask

    // acknowledge a transfer, handle the errors (in order)
    task automatic ack_tf_handle_err (
        ref tb_dma_job_t now_r
    );
        // internal signals
        logic                error;
        logic                last;
        idma_pkg::err_type_t err_type;
        axi_pkg::resp_t      cause;
        addr_t               burst_addr;
        int                  err_idx [$];
        // multiple errors can happen -> once one occurs
        // handle it after checking the list
        while (1) begin
            drv.wait_tf(cause, err_type, burst_addr, error, last);
            // if bus error occurs
            if (error & (err_type == idma_pkg::BUS_READ | err_type == idma_pkg::BUS_WRITE) & ErrorCap == idma_pkg::ERROR_HANDLING) begin
                err_idx = now_r.err_addr.find_first_index with (item == burst_addr);
                // handle it
                drv.handle_error(now_r.err_action[err_idx[0]]);
            // if transfer length zero happens:
            end else if (error & err_type == idma_pkg::BACKEND) begin
                break;
            end else begin
                break;
            end
        end
    endtask

    // initialize a memory region with 0 in both memories
    task automatic zero_mem (
        ref tb_dma_job_t now_r
    );
        addr_t now;
        now = 0;
        while (now < now_r.length) begin
            model.write_byte   ('0, now_r.src_addr + now);
            write_byte_axi_mem ('0, now_r.src_addr + now);
            now++;
        end
        // write errors
        for (int i = 0; i < now_r.err_addr.size(); i++) begin
            set_error_mem(
                          now_r.err_addr[i],
                          now_r.err_is_read[i],
                          axi_pkg::RESP_SLVERR
                         );
        end
    endtask

    // initialize a memory region with random data in both memories
    task automatic init_mem (
        ref tb_dma_job_t now_r
    );
        addr_t now;
        byte_t to_write;
        now = 0;
        while (now < now_r.length) begin
            // to_write = $urandom();
            to_write = now_r.src_addr + now;
            model.write_byte   (to_write, now_r.src_addr + now);
            write_byte_axi_mem (to_write, now_r.src_addr + now);
            now++;
        end
        // write errors
        for (int i = 0; i < now_r.err_addr.size(); i++) begin
            set_error_mem(
                          now_r.err_addr[i],
                          now_r.err_is_read[i],
                          axi_pkg::RESP_SLVERR
                         );
        end
    endtask

    // read jobs from the job file
    task automatic read_jobs (
        input string       filename,
        ref   tb_dma_job_t jobs [$]
    );

        // job file
        integer job_file;

        // parsed fields
        int unsigned            num_errors;
        string                  is_read, error_handling;
        addr_t                  err_addr;
        tb_dma_job_t            now;
        idma_pkg::idma_eh_req_t eh;

        // open file
        job_file = $fopen(filename, "r");

        // check if file exist
        if (job_file == 0)
            $fatal(1, "File not found!");

        // until not end of file
        while (! $feof(job_file)) begin
            now = new();
            void'($fscanf(job_file, "%d\n", now.length));
            void'($fscanf(job_file, "0x%x\n", now.src_addr));
            void'($fscanf(job_file, "0x%x\n", now.dst_addr));
            void'($fscanf(job_file, "%d\n", now.max_src_len));
            void'($fscanf(job_file, "%d\n", now.max_dst_len));
            void'($fscanf(job_file, "%b\n", now.aw_decoupled));
            void'($fscanf(job_file, "%b\n", now.rw_decoupled));
            if (now.IsND) begin
                for (int d = 0; d < now.NumDim-1; d++) begin
                    void'($fscanf(job_file, "%d\n", now.n_dims[d].reps));
                    void'($fscanf(job_file, "0x%x\n", now.n_dims[d].src_strides));
                    void'($fscanf(job_file, "0x%x\n", now.n_dims[d].dst_strides));
                end
            end
            void'($fscanf(job_file, "%d\n", num_errors));
            for (int i = 0; i < num_errors; i++) begin
                void'($fscanf(job_file, "%c%c0x%h\n", is_read, error_handling, err_addr));
                // parse error handling option
                eh = '0;
                case (error_handling)
                    "c" : eh = idma_pkg::CONTINUE;
                    "a" : eh = idma_pkg::ABORT;
                    default:;
                endcase
                now.err_action.push_back(eh);

                // parse read flag
                if (is_read == "r") begin
                    now.err_is_read.push_back(1);
                end else begin
                    now.err_is_read.push_back(0);
                end

                // error address
                now.err_addr.push_back(err_addr);
            end
            jobs.push_back(now);
        end

        // close job file
        $fclose(job_file);

    endtask

    // print a job summary (# jobs and total length)
    task automatic print_summary (
        ref   tb_dma_job_t jobs [$]
    );
        int unsigned data_size;
        int unsigned num_transfers;
        data_size     = '0;
        num_transfers = jobs.size();
        // go through queue
        for (int i = 0; i < num_transfers; i++) begin
            data_size = data_size + jobs[i].length;
        end
        $display("Launching %d jobs copying a total of %d B (%d kiB - %d MiB)",
                 num_transfers,
                 data_size,
                 data_size / 1024,
                 data_size / 1024 / 1024
                );
    endtask
