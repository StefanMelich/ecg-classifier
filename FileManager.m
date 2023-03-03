classdef FileManager
    %FILEMANAGER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        X
        Y
        welchX
        welchY
        MatrixN
        MatrixP
        PCAMatrix
        FuzzyMatrix
        NegativeCount
        PositiveCount
    end
    
    methods
        function filemanager = FileManager()
            %FILEMANAGER Construct an instance of this class
            %   Detailed explanation goes here
            MatrixN = double.empty;
            MatrixP = double.empty;
            PCAMatrix = double.empty;
            FuzzyMatrix = double.empty;
            NegativeCount = 0;
            PositiveCount = 0;
            filemanager = filemanager.WorkWithFolder();
            filemanager = filemanager.Welch();
            filemanager = filemanager.PCA();
            filemanager = filemanager.Fuzzy();

            filemanager.classification();

%             filemanager.PCAMatrix = filemanager.AddMatrixHeader(filemanager.PCAMatrix);
%             filemanager.FuzzyMatrix = filemanager.AddMatrixHeader(filemanager.FuzzyMatrix);

            
        end

        function matrix = AddMatrixHeader(obj, matrix)
            N = zeros(1, obj.NegativeCount);
            P = ones(1, obj.PositiveCount);
            tableHeader = [N P];
            % append first line
            matrix = [tableHeader; matrix];
        end

        function obj = ReadFile(obj)
            [file,path] = uigetfile('*.crv');
            if isequal(file,0)
               disp('User selected Cancel');
            else
               disp(['User selected ', fullfile(path,file)]);
               x = dlmread(fullfile(path,file), ' ', 5, 0);
               obj.Y = x(:, 1);
               N = size(obj.Y,1);
               Fs = 512;
               dt = 1/Fs;
               obj.X = dt*(0:N-1)';
            end
        end

        function obj = ReadFiles(path, path2, obj)
            [file,path] = uigetfile('*.crv');
            if isequal(file,0)
               disp('User selected Cancel');
            else
               disp(['User selected ', fullfile(path,file)]);
               x = dlmread(fullfile(path,file), ' ', 5, 0);
               obj.Y = x(:, 1);
               N = size(obj.Y,1);
               Fs = 512;
               dt = 1/Fs;
               obj.X = dt*(0:N-1)';
            end
        end

        function obj = Welch(obj)
            obj.MatrixN = pwelch(obj.MatrixN);
            obj.MatrixP = pwelch(obj.MatrixP);
            writematrix(obj.MatrixN, "outputWelchN.txt");
            writematrix(obj.MatrixP, "outputWelchP.txt");
        end

        function [obj, Matica] = PCA(obj)
            obj.PCAMatrix = [obj.MatrixN obj.MatrixP];
            
            % transpose matrix
            obj.PCAMatrix = obj.PCAMatrix.';

            %[coeff, score, latent] = pca(obj.PCAMatrix, 'NumComponents', 6);
            [coeff, score, latent, tsquared, explained, mu] = pca(obj.PCAMatrix, 'NumComponents', 6);
            % coeff = pca(obj.PCAMatrix, 'Centered', false);

            bar(latent) % explained is in percentage


            avg = mean(latent);
            count = 0;
            for i = 1 : size(latent)
                if latent(i) > avg
                    count = count + 1;
                end
            end
 
            % obj.PCAMatrix = score(:, (1:count));
            % spravim tabulku zo score (score je vystupna matica z PCA)
            tab1 = array2table(score);
            % pridam zahlavie tabulky s nazvom "outputClass"
            N = zeros(1, obj.NegativeCount);
            P = ones(1, obj.PositiveCount);
            tableHeader = [N P];
            tableHeader = tableHeader.';
            tab1.outputClass = tableHeader;
            % feature selection
            [idx, score] = fscchi2(tab1, "outputClass");
            
            obj.PCAMatrix = obj.PCAMatrix.';

            
            % writematrix(obj.Matrix, "outputPCA.txt");
            % writematrix(tableHeader, "header.txt");

            writematrix(obj.PCAMatrix, "outputPCA.txt");
            Matica = obj.PCAMatrix;
            %CreateTree(obj);
        end



        function obj = classification(obj)
            N = zeros(1, obj.NegativeCount);
            P = ones(1, obj.PositiveCount);
            tableHeader = [N P];
            tableHeader = tableHeader.';
            
            table = array2table(obj.PCAMatrix.');
            table.outputClass = tableHeader;
            tree = fitctree(table, "outputClass");
            CVtree = crossval(tree);
%             disp(CVtree);
            kfoldLoss(CVtree)
        end

        %zobrazi sa okno kde si vyberieme priecinok, prejde si kazdy subor
        %csv ktory je v nom
        function obj = WorkWithFolder(obj)
            obj = ReadData(obj, "\Negative\");
            obj = ReadData(obj, "\Positive\");
        end

        function obj = ReadData(obj, path)
            folderName = path;
            currentFolder = pwd;
            path = pwd + path;
            cd(path);
            listing = dir('*.crv');
            cd(currentFolder);
            for i = 1 : length(listing)
                thisfilename = listing(i).name;
                x = dlmread(fullfile(path,thisfilename), ' ', 5, 0);
                %x = x';
                if  folderName == "\Negative\"
                    obj.MatrixN = [obj.MatrixN x];
                    obj.NegativeCount = length(listing);
                elseif folderName == "\Positive\"
                    obj.MatrixP = [obj.MatrixP x];
                    obj.PositiveCount = length(listing);
                end
            end
        end

        function obj = CreateTree(obj)
            tab = array2table(obj.Matrix');
            writetable(tab, "tab.txt");
            tree = fitctree(tab, "Var1");
            view(tree,'Mode','graph');
            treeval = crossval(tree, 'Holdout', 0.25);
            kfoldLoss(treeval);
        end

        function obj = Fuzzy(obj)
            [rowCount, columnCount] = size(obj.PCAMatrix); % zisti pocet prvkov v riadku, stlpci
            for i = 1 : columnCount
                column = obj.PCAMatrix(:, i); % zoberie stlpec matice
                [idx, C] = kmeans(column,3); % v matici C su centra, pre pouzitie do vzorca
                C = sort(C); % zoradi centra od najmensieho
                newColumn = trimf(column, C); % vysledok, stlpec po fuzzyfikacii
                obj.FuzzyMatrix = [obj.FuzzyMatrix newColumn]; % prida stlpec do matice
            end
        end
    end
end

