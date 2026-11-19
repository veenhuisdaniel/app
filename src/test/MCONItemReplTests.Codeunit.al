codeunit 52999 "MCON Item Repl. Tests"
{
    Subtype = Test;

    [Test]
    procedure ScoresMapByItemNotPosition()
    var
        TempCandidates: Record "MCON Item Repl. Result" temporary;
        Workflow: Codeunit "MCON Item Repl. Workflow";
    begin
        SeedCandidates(TempCandidates);
        if not Workflow.ReadScores(
            '{"scores":[{"itemNo":"B","similarityScore":0.9,"reason":"Better match"},{"itemNo":"A","similarityScore":0.75,"reason":"Acceptable"}]}',
            TempCandidates)
        then
            Error(GetLastErrorText());
        TempCandidates.Get(1);
        if (TempCandidates."Similarity Score" <> 0.75) or (TempCandidates."Selection Reason" <> 'Acceptable') then
            Error('The score was not assigned to item A.');
        TempCandidates.Get(2);
        if TempCandidates."Similarity Score" <> 0.9 then
            Error('The score was not assigned to item B.');
    end;

    [Test]
    procedure MissingAndUnknownAreRejected()
    var
        TempCandidates: Record "MCON Item Repl. Result" temporary;
        Workflow: Codeunit "MCON Item Repl. Workflow";
    begin
        SeedCandidates(TempCandidates);
        if Workflow.ReadScores('{"scores":[]}', TempCandidates) then
            Error('Missing scores were accepted.');
        if Workflow.ReadScores(
            '{"scores":[{"itemNo":"C","similarityScore":0.9,"reason":"Unknown"},{"itemNo":"B","similarityScore":0.8,"reason":"Known"}]}',
            TempCandidates)
        then
            Error('An unknown candidate was accepted.');
    end;

    [Test]
    procedure DuplicateCandidatesAreRejected()
    var
        TempCandidates: Record "MCON Item Repl. Result" temporary;
        Workflow: Codeunit "MCON Item Repl. Workflow";
    begin
        SeedCandidates(TempCandidates);
        if Workflow.ReadScores(
            '{"scores":[{"itemNo":"A","similarityScore":0.9,"reason":"First"},{"itemNo":"A","similarityScore":0.8,"reason":"Duplicate"}]}',
            TempCandidates)
        then
            Error('A duplicate score was accepted.');
    end;

    [Test]
    procedure InvalidScoreValuesAreRejected()
    var
        TempCandidates: Record "MCON Item Repl. Result" temporary;
    begin
        SeedCandidates(TempCandidates);
        RejectScore(TempCandidates, 'null');
        RejectScore(TempCandidates, '"0.9"');
        RejectScore(TempCandidates, '1.01');
        RejectScore(TempCandidates, '-0.01');
        RejectScore(TempCandidates, '{}');
    end;

    [Test]
    procedure AgentErrorIsNotEmptySuccess()
    var
        TempCandidates: Record "MCON Item Repl. Result" temporary;
        Workflow: Codeunit "MCON Item Repl. Workflow";
    begin
        SeedCandidates(TempCandidates);
        if Workflow.ReadScores('{"error":{"reason":"unavailable"},"scores":[]}', TempCandidates) then
            Error('An agent error was accepted.');
        if Workflow.ReadScores('not JSON', TempCandidates) then
            Error('Invalid JSON was accepted.');
    end;

    [Test]
    procedure ThresholdAndTieAreDeterministic()
    var
        TempCandidates: Record "MCON Item Repl. Result" temporary;
        Workflow: Codeunit "MCON Item Repl. Workflow";
    begin
        SeedCandidates(TempCandidates);
        TempCandidates.Get(1);
        TempCandidates."Replacement Item No." := 'B';
        TempCandidates."Similarity Score" := 0.75;
        TempCandidates.Modify();
        TempCandidates.Get(2);
        TempCandidates."Replacement Item No." := 'A';
        TempCandidates."Similarity Score" := 0.75;
        TempCandidates.Modify();
        Workflow.MarkBestCandidate(TempCandidates);
        TempCandidates.Get(2);
        if not TempCandidates.Recommended then
            Error('At the exact threshold, item number must break the tie independently of insertion order.');
        TempCandidates.ModifyAll("Similarity Score", 0.7499);
        Workflow.MarkBestCandidate(TempCandidates);
        TempCandidates.SetRange(Recommended, true);
        if not TempCandidates.IsEmpty() then
            Error('A score below 0.75 was recommended.');
        TempCandidates.Reset();
        TempCandidates.Get(1);
        if TempCandidates."Result Reason" = '' then
            Error('No-match explanation is missing.');
    end;

    [Test]
    [HandlerFunctions('RejectReplacement')]
    procedure RejectingDoesNotReadSalesData()
    var
        TempCandidate: Record "MCON Item Repl. Result" temporary;
        Workflow: Codeunit "MCON Item Repl. Workflow";
    begin
        TempCandidate."Replacement Item No." := 'B';
        TempCandidate."Validation Status" := 'ASSESSED';
        if Workflow.ApplyReplacement(TempCandidate) then
            Error('Rejecting the confirmation must not apply a replacement.');
    end;

    [ConfirmHandler]
    procedure RejectReplacement(Question: Text[1024]; var Reply: Boolean)
    begin
        if Question = '' then
            Error('The replacement confirmation must explain the change.');
        Reply := false;
    end;

    [Test]
    procedure OriginalAndCandidatesAreSeparate()
    var
        TempSalesLine: Record "Sales Line" temporary;
        TempCandidates: Record "MCON Item Repl. Result" temporary;
        TempResults: Record "MCON Item Repl. Result" temporary;
        Workflow: Codeunit "MCON Item Repl. Workflow";
        NextEntryNo: Integer;
    begin
        SeedOriginal(TempSalesLine);
        SeedCandidates(TempCandidates);
        TempCandidates.ModifyAll("Similarity Score", 0.8);
        Workflow.MarkBestCandidate(TempCandidates);
        NextEntryNo := 0;
        Workflow.AppendLineResults(TempSalesLine, 1, '', TempCandidates, TempResults, NextEntryNo);
        if TempResults.Count() <> 3 then
            Error('Expected one original row and two separate candidate rows.');
        TempResults.Get(1);
        if not TempResults."Is Original" or (TempResults.Indentation <> 0) or
           (TempResults."Original Item No." <> 'ORIGINAL') or (TempResults."Replacement Item No." <> '')
        then
            Error('The original must be a distinct parent row, not a replacement.');
        TempResults.Get(2);
        if TempResults."Is Original" or (TempResults.Indentation <> 1) or
           (TempResults."Replacement Item No." <> 'A') or not TempResults.Recommended
        then
            Error('The best candidate must be a separate child row immediately below the original.');
        TempResults.Get(3);
        if TempResults."Is Original" or (TempResults.Indentation <> 1) or (TempResults."Replacement Item No." <> 'B') then
            Error('The alternative candidate must remain a separate child row.');
    end;

    [Test]
    procedure NoCandidatesHaveHeaderDiagnostic()
    var
        TempSalesLine: Record "Sales Line" temporary;
        TempCandidates: Record "MCON Item Repl. Result" temporary;
        TempResults: Record "MCON Item Repl. Result" temporary;
        Workflow: Codeunit "MCON Item Repl. Workflow";
        NextEntryNo: Integer;
    begin
        SeedOriginal(TempSalesLine);
        NextEntryNo := 0;
        Workflow.AppendLineResults(TempSalesLine, 1, 'Category matches: 0', TempCandidates, TempResults, NextEntryNo);
        if TempResults.Count() <> 1 then
            Error('No candidates must not create a replacement row.');
        TempResults.Get(1);
        if not TempResults."Is Original" or (TempResults."Result Reason" = '') or
           (TempResults."Search Diagnostics" <> 'Category matches: 0')
        then
            Error('The original must carry the no-match status and diagnostic for the top-of-dialog message.');
    end;

    [Test]
    procedure LowScoresHaveOriginalWarning()
    var
        TempSalesLine: Record "Sales Line" temporary;
        TempCandidates: Record "MCON Item Repl. Result" temporary;
        TempResults: Record "MCON Item Repl. Result" temporary;
        Workflow: Codeunit "MCON Item Repl. Workflow";
        NextEntryNo: Integer;
    begin
        SeedOriginal(TempSalesLine);
        SeedCandidates(TempCandidates);
        TempCandidates.ModifyAll("Similarity Score", 0.7);
        Workflow.MarkBestCandidate(TempCandidates);
        NextEntryNo := 0;
        Workflow.AppendLineResults(TempSalesLine, 1, '', TempCandidates, TempResults, NextEntryNo);
        TempResults.Get(1);
        if not TempResults."Is Original" or (TempResults."Result Reason" = '') then
            Error('An insufficient AI score must produce a warning on the original for the top-of-dialog message.');
        TempResults.SetRange("Is Original", false);
        if TempResults.Count() <> 2 then
            Error('Low-scoring candidates must remain available for inspection.');
    end;

    local procedure SeedOriginal(var TempSalesLine: Record "Sales Line" temporary)
    begin
        TempSalesLine."Document Type" := TempSalesLine."Document Type"::Order;
        TempSalesLine."Document No." := 'TEST';
        TempSalesLine."Line No." := 10000;
        TempSalesLine."No." := 'ORIGINAL';
        TempSalesLine.Description := 'Original item';
        TempSalesLine."Outstanding Quantity" := 5;
        TempSalesLine."Outstanding Qty. (Base)" := 5;
    end;

    [Test]
    procedure PartialShipmentCanKeepHistory()
    var
        TempSalesLine: Record "Sales Line" temporary;
        Workflow: Codeunit "MCON Item Repl. Workflow";
    begin
        SeedOriginal(TempSalesLine);
        TempSalesLine.Type := TempSalesLine.Type::Item;
        TempSalesLine.Quantity := 10;
        TempSalesLine."Quantity Shipped" := 4;
        TempSalesLine."Quantity Invoiced" := 2;
        TempSalesLine."Outstanding Quantity" := 6;
        Workflow.CheckReplacementPostingState(TempSalesLine);
        if (TempSalesLine."Quantity Shipped" <> 4) or (TempSalesLine."Quantity Invoiced" <> 2) or
           (TempSalesLine."Outstanding Quantity" <> 6)
        then
            Error('Checking a partial shipment must allow and preserve the posted history and remaining quantity.');
    end;

    [Test]
    procedure InconsistentPostedQtyIsRejected()
    var
        TempSalesLine: Record "Sales Line" temporary;
        Workflow: Codeunit "MCON Item Repl. Workflow";
    begin
        SeedOriginal(TempSalesLine);
        TempSalesLine.Type := TempSalesLine.Type::Item;
        TempSalesLine.Quantity := 10;
        TempSalesLine."Quantity Shipped" := 4;
        TempSalesLine."Quantity Invoiced" := 5;
        TempSalesLine."Outstanding Quantity" := 6;
        asserterror Workflow.CheckReplacementPostingState(TempSalesLine);
    end;

    [Test]
    procedure InvalidRemainingQtyIsRejected()
    var
        TempSalesLine: Record "Sales Line" temporary;
        Workflow: Codeunit "MCON Item Repl. Workflow";
    begin
        SeedOriginal(TempSalesLine);
        TempSalesLine.Type := TempSalesLine.Type::Item;
        TempSalesLine.Quantity := 10;
        TempSalesLine."Quantity Shipped" := 4;
        TempSalesLine."Outstanding Quantity" := 5;
        asserterror Workflow.CheckReplacementPostingState(TempSalesLine);
        TempSalesLine."Quantity Shipped" := 10;
        TempSalesLine."Outstanding Quantity" := 0;
        asserterror Workflow.CheckReplacementPostingState(TempSalesLine);
    end;

    [Test]
    procedure NewLineIsAppendedToSameOrder()
    var
        TempSalesLines: Record "Sales Line" temporary;
        Workflow: Codeunit "MCON Item Repl. Workflow";
        NextLineNo: Integer;
    begin
        TempSalesLines."Document Type" := TempSalesLines."Document Type"::Order;
        TempSalesLines."Document No." := 'TEST';
        TempSalesLines."Line No." := 10000;
        TempSalesLines.Insert();
        TempSalesLines."Line No." := 20000;
        TempSalesLines.Insert();
        TempSalesLines."Document No." := 'OTHER';
        TempSalesLines."Line No." := 90000;
        TempSalesLines.Insert();
        NextLineNo := Workflow.GetNextSalesLineNo(TempSalesLines, 'TEST');
        if NextLineNo <> 30000 then
            Error('The new line must follow the last line of the same order, not another document.');
    end;

    [Test]
    procedure ExhaustedLineNumbersAreRejected()
    var
        TempSalesLines: Record "Sales Line" temporary;
        Workflow: Codeunit "MCON Item Repl. Workflow";
    begin
        TempSalesLines."Document Type" := TempSalesLines."Document Type"::Order;
        TempSalesLines."Document No." := 'TEST';
        TempSalesLines."Line No." := 2147480000;
        TempSalesLines.Insert();
        asserterror Workflow.GetNextSalesLineNo(TempSalesLines, 'TEST');
    end;

    local procedure SeedCandidates(var TempCandidates: Record "MCON Item Repl. Result" temporary)
    begin
        TempCandidates.Init();
        TempCandidates."Entry No." := 1;
        TempCandidates."Replacement Item No." := 'A';
        TempCandidates.Insert();
        TempCandidates."Entry No." := 2;
        TempCandidates."Replacement Item No." := 'B';
        TempCandidates.Insert();
    end;

    local procedure RejectScore(var TempCandidates: Record "MCON Item Repl. Result" temporary; ScoreJson: Text)
    var
        Workflow: Codeunit "MCON Item Repl. Workflow";
    begin
        if Workflow.ReadScores(
            '{"scores":[{"itemNo":"A","similarityScore":' + ScoreJson +
            ',"reason":"Test"},{"itemNo":"B","similarityScore":0.8,"reason":"Valid"}]}', TempCandidates)
        then
            Error('An invalid score was accepted: %1', ScoreJson);
    end;
}
